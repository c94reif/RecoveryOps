import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
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
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance {
    sub = messaging.onMessageReceived.listen(onMessage);
    loadFromDb();
    startRemoteSyncPolling();
  }

  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    reports.addAll(rows);
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
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
