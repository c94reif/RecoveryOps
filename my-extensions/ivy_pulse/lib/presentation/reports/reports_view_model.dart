import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;

import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
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

/// Bumper numbers are only unique within a unit.
typedef ReportVehicleKey = ({String bumperNumber, String uic});

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
  StreamSubscription<void>? deliverySubscription;
  Future<void>? syncInFlight;
  Future<void>? queueRefreshInFlight;
  bool queueRefreshAgain = false;
  bool disposed = false;
  List<PmcsReport>? cachedYours, cachedExternal, cachedUnit, cachedOther;
  final vehicleGroups = Expando<Map<ReportVehicleKey, List<PmcsReport>>>();

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
  final ValueNotifier<PmcsReport?> reportToOpen = ValueNotifier(null);

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
    DeliveryCoordinator? delivery,
  }) : snackBarService = snackBarService ?? SnackBarService.instance {
    deliverySubscription = delivery?.changes.listen((_) => refreshQueued());
    sub = messaging.onMessageReceived.listen(onMessage);
    loadFromDb();
    startRemoteSyncPolling();
  }

  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    if (disposed) return;
    final known = reports.map((r) => r.entityId).toSet();
    for (final row in rows) {
      if (known.add(row.entityId)) reports.add(row);
    }
    await loadMyUic();
    if (disposed) return;
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
    await refreshQueued();
  }

  Future<void> loadMyUic() async {
    try {
      final profile = await profileRepository.getProfile();
      myUic = (profile?.uic ?? '').trim().toUpperCase();
      invalidateReportViews();
    } catch (e) {
      debugPrint('[IvyPulse] could not read UIC for report filtering: $e');
    }
  }

  /// Reload the parked submissions behind the queued tab.
  ///
  /// The repository hands them back oldest first because that is the order
  /// the worker drains them in; the tab shows the reverse, so the submission
  /// an operator just watched fail is the one at the top.
  Future<void> refreshQueued() {
    if (queueRefreshInFlight != null) {
      queueRefreshAgain = true;
      return queueRefreshInFlight!;
    }
    return queueRefreshInFlight = refreshQueueUntilCurrent().whenComplete(() {
      queueRefreshInFlight = null;
    });
  }

  Future<void> refreshQueueUntilCurrent() async {
    do {
      queueRefreshAgain = false;
      try {
        final parked = await queuedRepository.getAll();
        if (disposed) return;
        queued
          ..clear()
          ..addAll(parked.reversed);
        await refreshQueuedCount();
        if (disposed) return;
        notifyListeners();
      } catch (e) {
        debugPrint('[IvyPulse] refreshQueued error: $e');
      }
    } while (queueRefreshAgain && !disposed);
  }

  void invalidateReportViews() {
    cachedYours = cachedExternal = cachedUnit = cachedOther = null;
  }

  void updateUnread() {
    invalidateReportViews();
    unreadCount.value = reports.where((r) => !r.isRead && !r.isOutgoing).length;
  }

  Future<void> refreshQueuedCount() async {
    try {
      final count = await queueWorker.pendingCount();
      if (!disposed) queuedCount.value = count;
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
    reports.removeWhere((r) => r.entityId == stored.entityId);
    reports.insert(0, stored);
    updateUnread();
    notifyListeners();
  }

  /// A PMCS this device just submitted, handed over by the inspection flow.
  ///
  /// Without this the YOURS tab only ever showed what was in the database
  /// when the app started — a walk-around submitted a minute ago was
  /// invisible until the next launch, and on the WebView build the next
  /// launch starts with an empty database, so it was invisible for good.
  /// [stored] is the row as the repository returned it, id and all, so
  /// delete and mark-read work on it the same as on anything loaded at start.
  /// A resubmission under an entity id already on the list replaces the old
  /// row rather than stacking a duplicate.
  Future<void> addOutgoing(PmcsReport stored) async {
    reports.removeWhere((r) => r.entityId == stored.entityId);
    reports.insert(0, stored);
    updateUnread();
    notifyListeners();
    // A submission that could not reach its transport is parked at the same
    // moment, so the QUEUED tab moves with it.
    await refreshQueuedCount();
    await refreshQueued();
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
      (_) => unawaited(syncRemoteLatticeReports().catchError((Object error) {
        debugPrint('[IvyPulse] Scheduled sync failed: $error');
      })),
    );
  }

  Future<void> syncRemoteLatticeReports() =>
      syncInFlight ??= performRemoteSync().whenComplete(() {
        syncInFlight = null;
      });

  Future<void> performRemoteSync() async {
    final newReports = await syncRemoteReports(reports);
    if (disposed) return;
    if (newReports.isNotEmpty) {
      for (final report in newReports) {
        reports.removeWhere((r) => r.entityId == report.entityId);
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
      cachedYours ??= List.unmodifiable(reports.where((r) => r.isOutgoing));

  List<PmcsReport> get externalReports =>
      cachedExternal ??= List.unmodifiable(reports.where((r) => !r.isOutgoing));

  /// True when a report was signed for under the same UIC as this device.
  /// With no UIC of our own to compare against, every crew counts as ours
  /// rather than none — see [myUic].
  bool isSameUnit(PmcsReport report) =>
      myUic.isEmpty || report.uic.trim().toUpperCase() == myUic;

  /// Other crews in your own unit.
  List<PmcsReport> get unitReports =>
      cachedUnit ??= List.unmodifiable(externalReports.where(isSameUnit));

  /// Everything else that arrived over the net. Kept reachable rather than
  /// filtered away: a RED X on an attached vehicle still deadlines it.
  List<PmcsReport> get otherUnitReports => cachedOther ??=
      List.unmodifiable(externalReports.where((r) => !isSameUnit(r)));

  /// One entry per bumper number and UIC, holding its PMCS newest first.
  Map<ReportVehicleKey, List<PmcsReport>> groupByVehicle(
      List<PmcsReport> source) {
    final cacheable = identical(source, cachedYours) ||
        identical(source, cachedExternal) ||
        identical(source, cachedUnit) ||
        identical(source, cachedOther);
    if (cacheable && vehicleGroups[source] != null) {
      return vehicleGroups[source]!;
    }
    final groups = <ReportVehicleKey, List<PmcsReport>>{};
    for (final report in source) {
      final vehicle = (
        bumperNumber: report.bumperNumber.trim().toUpperCase(),
        uic: report.uic.trim().toUpperCase(),
      );
      groups.putIfAbsent(vehicle, () => []).add(report);
    }
    for (final list in groups.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final bumperOrder = a.bumperNumber.compareTo(b.bumperNumber);
        return bumperOrder != 0 ? bumperOrder : a.uic.compareTo(b.uic);
      });
    final sorted = {for (final key in keys) key: groups[key]!};
    if (cacheable) vehicleGroups[source] = sorted;
    return sorted;
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
    disposed = true;
    deliverySubscription?.cancel();
    remoteSyncTimer?.cancel();
    sub?.cancel();
    unreadCount.dispose();
    queuedCount.dispose();
    reportToOpen.dispose();
    super.dispose();
  }
}
