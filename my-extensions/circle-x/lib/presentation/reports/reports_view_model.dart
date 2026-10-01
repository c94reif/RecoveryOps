import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/domain/entities/incoming_report_message.dart';
import 'package:circle_x/domain/services/report_message_source.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';
import 'package:circle_x/domain/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/usecases/map/show_report_on_map.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:circle_x/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:circle_x/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:circle_x/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:circle_x/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:circle_x/domain/usecases/reporting/store_received_report.dart';
import 'package:circle_x/presentation/common/services/snack_bar_service.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';
import 'package:circle_x/presentation/common/services/fault_suggestion_controller.dart';

export 'package:circle_x/domain/entities/pmcs_report.dart';
export 'package:circle_x/domain/entities/queued_submission.dart';

part 'reports_state.dart';
part 'reports_sync.dart';
part 'reports_queue.dart';
part 'reports_collection.dart';
part 'reports_actions.dart';

typedef ReportVehicleKey = ({String bumperNumber, String uic});

enum ReportsTab {
  yours('YOURS'),

  unit('MY UNIT'),

  queued('QUEUED');

  const ReportsTab(this.label);

  final String label;
}

/// Wires report workflows and owns their subscriptions and lifecycle.
class ReportsViewModel extends _ReportsState
    with _ReportsSync, _ReportsQueue, _ReportsCollection, _ReportsActions {
  final ReportMessageSource messaging;
  @override
  final ReportsRepository repository;
  @override
  final ParseIncomingReport parseIncomingReport;
  @override
  final ParseIncomingDeletion parseIncomingDeletion;
  @override
  final SyncRemoteReports syncRemoteReports;
  @override
  final SyncLocalReportsToLattice syncLocalReportsToLattice;
  @override
  final ShowReportOnMap showReportOnMap;
  @override
  final PublishPmcsDeletion publishPmcsDeletion;
  @override
  final QueueWorkerStrategy queueWorker;
  @override
  final ProfileRepository profileRepository;
  @override
  final QueuedSubmissionsRepository queuedRepository;
  @override
  final UserNotificationSink snackBarService;
  final FaultSuggestionController suggestions;
  final bool _ownsSuggestions;

  static const String bucketNotMissionCapable = 'NOT MISSION CAPABLE';
  static const String bucketLimited = 'LIMITED — CIRCLE X';
  static const String bucketMissionCapable = 'MISSION CAPABLE';

  static const List<String> statusBuckets = [
    bucketNotMissionCapable,
    bucketLimited,
    bucketMissionCapable,
  ];

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
        debugPrint('[CircleX] Initial report sync failed: $error');
      }
    }());
    startRemoteSyncPolling();
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
