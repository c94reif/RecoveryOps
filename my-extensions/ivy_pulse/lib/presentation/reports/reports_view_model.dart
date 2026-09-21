import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/usecases/map/show_report_on_map.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';

export 'package:ivy_pulse/domain/entities/pmcs_report.dart';
export 'package:ivy_pulse/domain/entities/queued_submission.dart';

/// The three views a maintainer flips between on the Reports tab.
enum ReportsTab {
  /// PMCS this device submitted.
  yours('YOURS'),

  /// PMCS from other crews signed for under the same UIC.
  unit('MY UNIT'),

  /// Submissions still parked because a transport was down.
  queued('QUEUED');

  const ReportsTab(this.label);

  final String label;
}

class ReportsViewModel extends ChangeNotifier {
  final sdk.MessagingService messaging;
  final ReportsRepository repository;
  final ParseIncomingReport parseIncomingReport;
  final ParseIncomingDeletion parseIncomingDeletion;
  final SyncRemoteReports syncRemoteReports;
  final SyncLocalReportsToLattice syncLocalReportsToLattice;
  final ShowReportOnMap showReportOnMap;
  final PublishPmcsDeletion publishPmcsDeletion;
  final QueueWorkerStrategy queueWorker;
  final ProfileRepository profileRepository;
  final QueuedSubmissionsRepository queuedRepository;
  final SnackBarService snackBarService;

  StreamSubscription<sdk.IncomingMessage>? sub;
  Timer? remoteSyncTimer;

  /// Section keys for [groupedByStatus], worst first — a maintainer triages
  /// deadlined vehicles before anything that can still roll.
  static const String bucketNotMissionCapable = 'NOT MISSION CAPABLE';
  static const String bucketLimited = 'LIMITED — CIRCLE X';
  static const String bucketMissionCapable = 'MISSION CAPABLE';

  static const List<String> statusBuckets = [
    bucketNotMissionCapable,
    bucketLimited,
    bucketMissionCapable,
  ];

  final List<PmcsReport> reports = [];
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  /// Submissions still parked because a transport was down. Surfaced so a
  /// Soldier never walks away believing a fault reached the maintainer.
  final ValueNotifier<int> queuedCount = ValueNotifier(0);

  String? activeMarkerId;

  /// The UIC this device is signed for, upper-cased once so every comparison
  /// against a report's UIC is a plain string match.
  ///
  /// Empty when the profile has not been read (or could not be). Nothing is
  /// hidden in that case — [unitReports] falls back to every report from
  /// another crew, because a unit we cannot name is not grounds for dropping
  /// a deadlined vehicle off the maintainer's screen.
  String myUic = '';

  /// Parked submissions, newest first — see [queuedByBumperNumber].
  final List<QueuedSubmission> queued = [];

  ReportsViewModel(
    this.messaging,
    this.repository,
    this.parseIncomingReport,
    this.parseIncomingDeletion,
    this.syncRemoteReports,
    this.syncLocalReportsToLattice,
    this.showReportOnMap,
    this.publishPmcsDeletion,
    this.queueWorker, {
    required this.profileRepository,
    required this.queuedRepository,
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance {
    sub = messaging.onMessageReceived.listen(onMessage);
    loadFromDb();
    startRemoteSyncPolling();
  }

  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    reports.addAll(rows);
    await loadMyUic();
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
    await refreshQueued();
  }

  Future<void> loadMyUic() async {
    try {
      final profile = await profileRepository.getProfile();
      myUic = (profile?.uic ?? '').trim().toUpperCase();
    } catch (e) {
      debugPrint('[IvyPulse] could not read UIC for report filtering: $e');
    }
  }

  /// Reload the parked submissions behind the queued tab.
  ///
  /// The repository hands them back oldest first because that is the order
  /// the worker drains them in; the tab shows the reverse, so the submission
  /// an operator just watched fail is the one at the top.
  Future<void> refreshQueued() async {
    try {
      final parked = await queuedRepository.getAll();
      queued
        ..clear()
        ..addAll(parked.reversed);
      notifyListeners();
    } catch (e) {
      debugPrint('[IvyPulse] refreshQueued error: $e');
    }
  }

  void updateUnread() {
    unreadCount.value = reports.where((r) => !r.isRead && !r.isOutgoing).length;
  }

  Future<void> refreshQueuedCount() async {
    try {
      queuedCount.value = await queueWorker.pendingCount();
    } catch (e) {
      debugPrint('[IvyPulse] refreshQueuedCount error: $e');
    }
  }

  void onMessage(sdk.IncomingMessage msg) {
    final report = parseIncomingReport(msg);
    if (report != null) {
      unawaited(storeIncomingReport(report));
      return;
    }

    final deletedEntityId = parseIncomingDeletion(msg);
    if (deletedEntityId != null) {
      applyRemoteDeletion(deletedEntityId);
    }
  }

  /// Holds the *stored* copy, not the parsed one.
  ///
  /// The row id only exists after the insert, and both marking a report read
  /// and honouring a withdrawal skip the database without it — so a mesh PMCS
  /// would come back unread after a restart, and a withdrawn vehicle would
  /// reappear on next launch.
  Future<void> storeIncomingReport(PmcsReport report) async {
    final stored = await repository.insertReport(report);
    reports.insert(0, stored);
    updateUnread();
    notifyListeners();
  }

  Future<void> applyRemoteDeletion(String entityId) async {
    final index = reports.indexWhere((r) => r.entityId == entityId);
    if (index == -1) return;
    final removed = reports.removeAt(index);
    updateUnread();
    if (removed.id != null) {
      await repository.deleteReport(removed.id!);
    }
    notifyListeners();
  }

  void startRemoteSyncPolling() {
    remoteSyncTimer = Timer.periodic(
      AppConstants.remoteSyncInterval,
      (_) => syncRemoteLatticeReports(),
    );
  }

  Future<void> syncRemoteLatticeReports() async {
    final newReports = await syncRemoteReports(reports);
    if (newReports.isNotEmpty) {
      for (final report in newReports) {
        reports.insert(0, report);
      }
      updateUnread();
      notifyListeners();
    }

    await syncLocalReportsToLattice(reports);
    await refreshQueuedCount();
    // Pull-to-refresh is the gesture an operator makes to ask "has my queue
    // moved?", so the parked list has to come back with it.
    await refreshQueued();
  }

  Future<void> markReportAsRead(PmcsReport report) async {
    if (report.isRead) return;
    final index = reports.indexOf(report);
    if (index == -1) return;
    reports[index] = report.copyWith(isRead: true);
    updateUnread();
    if (report.id != null) {
      await repository.markAsRead(report.id!);
    }
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var i = 0; i < reports.length; i++) {
      if (!reports[i].isRead) {
        reports[i] = reports[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      updateUnread();
      await repository.markAllAsRead();
      notifyListeners();
    }
  }

  Future<void> deleteReport(PmcsReport report) async {
    final index = reports.indexOf(report);
    if (index == -1) return;
    reports.removeAt(index);
    updateUnread();
    if (report.id != null) {
      await repository.deleteReport(report.id!);
    }
    notifyListeners();

    // Dropping our own PMCS locally is not enough — the entity is still on
    // every maintainer's map until it is withdrawn on both transports.
    if (report.isOutgoing && report.entityId.isNotEmpty) {
      final outcome = await publishPmcsDeletion(entityId: report.entityId);
      snackBarService.enqueue(
        'Withdrawal — Lattice: ${outcome.latticeOk ? 'sent' : 'FAILED'} | '
        'Mesh: ${outcome.meshOk ? 'sent' : 'FAILED'}',
        isError: !outcome.allSucceeded,
      );
    }
  }

  Future<void> viewReport(PmcsReport report) async {
    activeMarkerId = await showReportOnMap(
      report,
      previousMarkerId: activeMarkerId,
    );
    notifyListeners();
  }

  List<PmcsReport> get yourReports =>
      reports.where((r) => r.isOutgoing).toList();

  List<PmcsReport> get externalReports =>
      reports.where((r) => !r.isOutgoing).toList();

  /// True when a report was signed for under the same UIC as this device.
  /// With no UIC of our own to compare against, every crew counts as ours
  /// rather than none — see [myUic].
  bool isSameUnit(PmcsReport report) =>
      myUic.isEmpty || report.uic.trim().toUpperCase() == myUic;

  /// Other crews in your own unit.
  List<PmcsReport> get unitReports =>
      externalReports.where(isSameUnit).toList();

  /// Everything else that arrived over the net. Kept reachable rather than
  /// filtered away: a RED X on an attached vehicle still deadlines it.
  List<PmcsReport> get otherUnitReports =>
      externalReports.where((r) => !isSameUnit(r)).toList();

  /// One entry per vehicle, keyed by bumper number, each holding that
  /// vehicle's PMCS newest first. Vehicles come out in bumper-number order so
  /// a maintainer looking for one can run down the list.
  Map<String, List<PmcsReport>> groupByBumperNumber(List<PmcsReport> source) {
    final groups = <String, List<PmcsReport>>{};
    for (final report in source) {
      final bumper = report.bumperNumber.trim().toUpperCase();
      groups.putIfAbsent(bumper, () => []).add(report);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final keys = groups.keys.toList()..sort();
    return {for (final key in keys) key: groups[key]!};
  }

  /// Parked submissions per vehicle, last in first out.
  ///
  /// The vehicle whose submission was parked most recently leads, and within
  /// a vehicle the newest sits on top — the reverse of the order the worker
  /// will actually drain them in, which is what an operator asking "did my
  /// last one go?" is looking for.
  Map<String, List<QueuedSubmission>> get queuedByBumperNumber {
    final groups = <String, List<QueuedSubmission>>{};
    for (final submission in queued) {
      final bumper = submission.bumperNumber.trim().toUpperCase();
      groups.putIfAbsent(bumper, () => []).add(submission);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final keys = groups.keys.toList()
      ..sort((a, b) =>
          groups[b]!.first.createdAt.compareTo(groups[a]!.first.createdAt));
    return {for (final key in keys) key: groups[key]!};
  }

  /// The bucket a report is triaged into. RED X outranks everything else: one
  /// deadlining fault makes the vehicle Not Mission Capable regardless of what
  /// else was found.
  String bucketFor(PmcsReport report) {
    final tally = report.tally;
    if (tally.redX > 0) return bucketNotMissionCapable;
    if (tally.circleX > 0) return bucketLimited;
    return bucketMissionCapable;
  }

  Map<String, List<PmcsReport>> get groupedByStatus {
    final result = {
      for (final bucket in statusBuckets) bucket: <PmcsReport>[],
    };
    for (final report in externalReports) {
      result[bucketFor(report)]!.add(report);
    }
    for (final list in result.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return result;
  }

  @override
  void dispose() {
    remoteSyncTimer?.cancel();
    sub?.cancel();
    unreadCount.dispose();
    queuedCount.dispose();
    super.dispose();
  }
}
