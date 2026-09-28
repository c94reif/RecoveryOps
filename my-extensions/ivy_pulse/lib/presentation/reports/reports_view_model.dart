import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ivy_pulse/domain/entities/incoming_report_message.dart';
import 'package:ivy_pulse/domain/services/report_message_source.dart';

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
import 'package:ivy_pulse/presentation/common/services/snack_bar_service.dart';
import 'package:ivy_pulse/domain/services/user_notification_sink.dart';
import 'package:ivy_pulse/presentation/common/services/fault_suggestion_controller.dart';

export 'package:ivy_pulse/domain/entities/pmcs_report.dart';
export 'package:ivy_pulse/domain/entities/queued_submission.dart';

typedef ReportVehicleKey = ({String bumperNumber, String uic});

enum ReportsTab {
  yours('YOURS'),

  unit('MY UNIT'),

  queued('QUEUED');

  const ReportsTab(this.label);

  final String label;
}

class ReportsViewModel extends ChangeNotifier {
  final ReportMessageSource messaging;
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
  final UserNotificationSink snackBarService;
  final FaultSuggestionController suggestions;
  final bool _ownsSuggestions;

  StreamSubscription<IncomingReportMessage>? messageSubscription;
  Timer? remoteSyncTimer;
  StreamSubscription<void>? deliverySubscription;
  Future<void>? syncInFlight;
  Future<void>? queueRefreshInFlight;
  bool queueRefreshAgain = false;
  bool disposed = false;
  List<PmcsReport>? cachedYours, cachedExternal, cachedUnit, cachedOther;
  final vehicleGroups = Expando<Map<ReportVehicleKey, List<PmcsReport>>>();

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

  final ValueNotifier<int> queuedCount = ValueNotifier(0);

  String? activeMarkerId;

  String myUic = '';

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
    UserNotificationSink? snackBarService,
    DeliveryCoordinator? delivery,
    bool syncOnStart = true,
    FaultSuggestionController? suggestions,
  })  : suggestions = suggestions ??
            FaultSuggestionController(repository,
                notifications: snackBarService),
        _ownsSuggestions = suggestions == null,
        snackBarService = snackBarService ?? SnackBarService.instance {
    unawaited(this.suggestions.load());
    deliverySubscription = delivery?.changes.listen((_) => refreshQueued());
    messageSubscription = messaging.messages.listen(onMessage);
    unawaited(() async {
      try {
        await loadFromDb();
        if (syncOnStart && !disposed) await syncRemoteLatticeReports();
      } catch (error) {
        debugPrint('[IvyPulse] Initial report sync failed: $error');
      }
    }());
    startRemoteSyncPolling();
  }

  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    final withdrawn = await repository.getWithdrawnIds();
    if (disposed) return;
    final knownEntityIds =
        reports.map((candidateReport) => candidateReport.entityId).toSet();
    for (final row in rows) {
      if (withdrawn.contains(row.entityId)) continue;
      if (knownEntityIds.add(row.entityId)) reports.add(row);
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
    } catch (error) {
      debugPrint('[IvyPulse] could not read UIC for report filtering: $error');
    }
  }

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
      } catch (error) {
        debugPrint('[IvyPulse] refreshQueued error: $error');
      }
    } while (queueRefreshAgain && !disposed);
  }

  void invalidateReportViews() {
    cachedYours = cachedExternal = cachedUnit = cachedOther = null;
  }

  void updateUnread() {
    invalidateReportViews();
    unreadCount.value = reports
        .where((candidateReport) =>
            !candidateReport.isRead && !candidateReport.isOutgoing)
        .length;
  }

  Future<void> refreshQueuedCount() async {
    try {
      final count = await queueWorker.pendingCount();
      if (!disposed) queuedCount.value = count;
    } catch (error) {
      debugPrint('[IvyPulse] refreshQueuedCount error: $error');
    }
  }

  void onMessage(IncomingReportMessage message) {
    final report = parseIncomingReport(message);
    if (report != null) {
      unawaited(storeIncomingReport(report));
      return;
    }

    final deletedEntityId = parseIncomingDeletion(message);
    if (deletedEntityId != null) {
      applyRemoteDeletion(deletedEntityId);
    }
  }

  Future<void> storeIncomingReport(PmcsReport report) async {
    try {
      final stored = await repository.insertReport(report);
      if (disposed ||
          (await repository.getWithdrawnIds()).contains(stored.entityId)) {
        return;
      }
      if (disposed) return;
      reports.removeWhere(
          (candidateReport) => candidateReport.entityId == stored.entityId);
      reports.insert(0, stored);
      updateUnread();
      notifyListeners();
    } on ReportWithdrawn {
      return;
    } catch (error) {
      debugPrint('[IvyPulse] Could not store incoming report: $error');
    }
  }

  Future<void> addOutgoing(PmcsReport stored) async {
    reports.removeWhere(
        (candidateReport) => candidateReport.entityId == stored.entityId);
    reports.insert(0, stored);
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
    await refreshQueued();
  }

  Future<void> applyRemoteDeletion(String entityId) async {
    try {
      await repository.withdrawReport(entityId);
      if (disposed) return;
      reports.removeWhere(
          (candidateReport) => candidateReport.entityId == entityId);
      updateUnread();
      notifyListeners();
    } catch (error) {
      debugPrint('[IvyPulse] Could not store withdrawal: $error');
    }
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
    final withdrawn = await repository.getWithdrawnIds();
    if (disposed) return;
    if (newReports.isNotEmpty || withdrawn.isNotEmpty) {
      reports.removeWhere(
          (candidateReport) => withdrawn.contains(candidateReport.entityId));
      for (final report in newReports) {
        if (withdrawn.contains(report.entityId)) continue;
        reports.removeWhere(
            (candidateReport) => candidateReport.entityId == report.entityId);
        reports.insert(0, report);
      }
      updateUnread();
      notifyListeners();
    }

    await syncLocalReportsToLattice(reports);
    await refreshQueuedCount();
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
    for (var reportIndex = 0; reportIndex < reports.length; reportIndex++) {
      if (!reports[reportIndex].isRead) {
        reports[reportIndex] = reports[reportIndex].copyWith(isRead: true);
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
    if (!reports.contains(report)) return;
    if (report.isOutgoing && report.entityId.isNotEmpty) {
      try {
        final outcome = await publishPmcsDeletion(report);
        snackBarService.enqueue(
          'Withdrawal — Lattice: ${outcome.latticeOk ? 'sent' : 'queued'} | '
          'Mesh: ${outcome.meshOk ? 'sent' : 'queued'}',
          isError: !outcome.allSucceeded,
        );
      } catch (error) {
        snackBarService.enqueue('Could not save withdrawal. Please retry.',
            isError: true);
        return;
      }
    } else if (report.id != null) {
      await repository.deleteReport(report.id!);
    }
    if (disposed) return;
    reports.removeWhere(
        (candidateReport) => candidateReport.entityId == report.entityId);
    updateUnread();
    notifyListeners();
    await refreshQueued();
  }

  Future<void> viewReport(PmcsReport report) async {
    activeMarkerId = await showReportOnMap(
      report,
      previousMarkerId: activeMarkerId,
    );
    notifyListeners();
  }

  List<PmcsReport> get yourReports => cachedYours ??= List.unmodifiable(
      reports.where((candidateReport) => candidateReport.isOutgoing));

  List<PmcsReport> get externalReports => cachedExternal ??= List.unmodifiable(
      reports.where((candidateReport) => !candidateReport.isOutgoing));

  bool isSameUnit(PmcsReport report) =>
      myUic.isEmpty || report.uic.trim().toUpperCase() == myUic;

  List<PmcsReport> get unitReports =>
      cachedUnit ??= List.unmodifiable(externalReports.where(isSameUnit));

  List<PmcsReport> get otherUnitReports => cachedOther ??= List.unmodifiable(
      externalReports.where((candidateReport) => !isSameUnit(candidateReport)));

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
      list.sort((first, second) => second.timestamp.compareTo(first.timestamp));
    }
    final keys = groups.keys.toList()
      ..sort((first, second) {
        final bumperOrder = first.bumperNumber.compareTo(second.bumperNumber);
        return bumperOrder != 0 ? bumperOrder : first.uic.compareTo(second.uic);
      });
    final sorted = {for (final key in keys) key: groups[key]!};
    if (cacheable) vehicleGroups[source] = sorted;
    return sorted;
  }

  Map<String, List<QueuedSubmission>> get queuedByBumperNumber {
    final groups = <String, List<QueuedSubmission>>{};
    for (final submission in queued) {
      final bumper = submission.bumperNumber.trim().toUpperCase();
      groups.putIfAbsent(bumper, () => []).add(submission);
    }
    for (final list in groups.values) {
      list.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    }
    final keys = groups.keys.toList()
      ..sort((first, second) => groups[second]!
          .first
          .createdAt
          .compareTo(groups[first]!.first.createdAt));
    return {for (final key in keys) key: groups[key]!};
  }

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
      list.sort((first, second) => second.timestamp.compareTo(first.timestamp));
    }
    return result;
  }

  @override
  void dispose() {
    if (_ownsSuggestions) suggestions.dispose();
    disposed = true;
    deliverySubscription?.cancel();
    remoteSyncTimer?.cancel();
    messageSubscription?.cancel();
    unreadCount.dispose();
    queuedCount.dispose();
    reportToOpen.dispose();
    super.dispose();
  }
}
