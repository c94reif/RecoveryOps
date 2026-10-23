import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/data/services/delivery/report_store_factory.dart';
import 'package:circle_x/domain/delivery/services/report_store_backend.dart';
import 'package:circle_x/domain/delivery/services/report_store_strategy.dart';
import 'package:circle_x/data/services/shared/flutter_diagnostic_logger.dart';
import 'package:circle_x/data/services/map/sdk_report_map_adapter.dart';
import 'package:circle_x/data/services/delivery/sdk_report_message_source.dart';
import 'package:circle_x/domain/shared/services/diagnostic_logger.dart';
import 'package:circle_x/domain/map/services/report_map_port.dart';
import 'package:circle_x/domain/delivery/services/report_message_source.dart';
import 'package:circle_x/domain/shared/services/transaction_runner.dart';
import 'package:circle_x/domain/shared/services/user_notification_sink.dart';
import 'package:circle_x/domain/notifications/services/pmcs_notification_port.dart';
import 'package:circle_x/data/services/notifications/android_pmcs_notifications.dart';
import 'package:circle_x/presentation/common/services/snack_bar_service.dart';
import 'package:circle_x/core/di/service_locator.dart';
export 'package:circle_x/core/di/service_locator.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/catalog/pmcs_reference_data.g.dart';
import 'package:circle_x/data/dao/faults/pmcs_faults_dao.dart';
import 'package:circle_x/data/dao/profile/profile_dao.dart';
import 'package:circle_x/data/dao/queue/queued_submissions_dao.dart';
import 'package:circle_x/data/dao/reports/pmcs_reports_dao.dart';
import 'package:circle_x/data/dao/results/check_results_dao.dart';
import 'package:circle_x/data/dao/sessions/sessions_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_entity_mapper.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/repositories/faults_repo_impl.dart';
import 'package:circle_x/data/repositories/location_repo_impl.dart';
import 'package:circle_x/data/repositories/profile_repo_impl.dart';
import 'package:circle_x/data/repositories/queued_submissions_repo_impl.dart';
import 'package:circle_x/data/repositories/reports_repo_impl.dart';
import 'package:circle_x/data/repositories/results_repo_impl.dart';
import 'package:circle_x/data/repositories/sessions_repo_impl.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:circle_x/data/services/vehicle/bumper_scanner_factory.dart';
import 'package:circle_x/data/services/shared/device_speech_recognition.dart';
import 'package:circle_x/data/services/shared/drift_transaction_runner.dart';
import 'package:circle_x/data/services/delivery/queue_worker_factory.dart';
import 'package:circle_x/data/services/delivery/sdk_mesh_broadcaster.dart';
import 'package:circle_x/data/services/catalog/static_pmcs_catalog_source.dart';
import 'package:circle_x/data/services/shared/system_id_generator.dart';
import 'package:circle_x/domain/inspection/services/tm_fault_classifier.dart';
import 'package:circle_x/domain/inspection/repositories/faults_repo.dart';
import 'package:circle_x/domain/shared/repositories/location_repo.dart';
import 'package:circle_x/domain/profile/repositories/profile_repo.dart';
import 'package:circle_x/domain/delivery/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/reporting/repositories/reports_repo.dart';
import 'package:circle_x/domain/inspection/repositories/results_repo.dart';
import 'package:circle_x/domain/inspection/repositories/sessions_repo.dart';
import 'package:circle_x/domain/vehicle/services/bumper_scanner_strategy.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:circle_x/domain/inspection/services/fault_classifier_strategy.dart';
import 'package:circle_x/domain/shared/services/id_generator.dart';
import 'package:circle_x/domain/delivery/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/catalog/services/pmcs_catalog_source.dart';
import 'package:circle_x/domain/delivery/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/delivery/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/delivery/services/remote_report_source.dart';
import 'package:circle_x/domain/reporting/services/report_codec.dart';
import 'package:circle_x/domain/shared/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/inspection/usecases/build_phase_faults.dart';
import 'package:circle_x/domain/map/usecases/show_report_on_map.dart';
import 'package:circle_x/domain/inspection/usecases/suggest_parts_for_fault.dart';
import 'package:circle_x/domain/delivery/usecases/publish_pmcs_deletion.dart';
import 'package:circle_x/domain/delivery/usecases/publish_pmcs_report.dart';
import 'package:circle_x/domain/reporting/usecases/build_session_report.dart';
import 'package:circle_x/domain/delivery/usecases/parse_incoming_deletion.dart';
import 'package:circle_x/domain/delivery/usecases/parse_incoming_report.dart';
import 'package:circle_x/domain/reporting/usecases/submit_session.dart';
import 'package:circle_x/domain/reporting/usecases/submit_maintainer_review.dart';
import 'package:circle_x/domain/delivery/usecases/sync_local_reports_to_lattice.dart';
import 'package:circle_x/domain/delivery/usecases/sync_remote_reports.dart';
import 'package:circle_x/domain/inspection/usecases/abandon_session.dart';
import 'package:circle_x/domain/inspection/usecases/complete_phase.dart';
import 'package:circle_x/domain/inspection/usecases/load_open_sessions.dart';
import 'package:circle_x/domain/inspection/usecases/record_check_result.dart';
import 'package:circle_x/domain/inspection/usecases/start_session.dart';
import 'package:circle_x/presentation/common/services/fault_suggestion_controller.dart';
import 'package:circle_x/presentation/home/home_view_model.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

void configureDependencies(
  sdk.ExtensionContext extensionContext, {
  ReportStoreBackend? reportStoreBackend,
  sdk.MeshDataTypePath reportItemType = ReportStoreConfig.itemType,
}) {
  getIt.registerLazySingleton<sdk.ExtensionContext>(() => extensionContext);
  getIt.registerLazySingleton<sdk.LocationService>(
      () => extensionContext.location);
  getIt.registerLazySingleton<sdk.MapService>(() => extensionContext.map);
  getIt.registerLazySingleton<sdk.SpeechService>(() => extensionContext.speech);
  getIt.registerLazySingleton<sdk.StorageService>(
      () => extensionContext.storage);
  getIt.registerLazySingleton<sdk.MessagingService>(
      () => extensionContext.messaging);
  getIt.registerLazySingleton<sdk.EntityService>(
      () => extensionContext.entities);

  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  getIt.registerLazySingleton<TransactionRunner>(
    () => DriftTransactionRunner(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<DiagnosticLogger>(
    () => const FlutterDiagnosticLogger(),
  );
  getIt.registerLazySingleton<UserNotificationSink>(
    () => SnackBarService.instance,
  );
  getIt.registerLazySingleton<PmcsNotificationPort>(createPmcsNotifications);
  getIt.registerLazySingleton<ReportMapPort>(
    () => SdkReportMapAdapter(getIt<sdk.MapService>()),
  );
  getIt.registerLazySingleton<ReportMessageSource>(
    () => SdkReportMessageSource(getIt<sdk.MessagingService>()),
  );
  getIt.registerLazySingleton<ProfileDao>(
      () => ProfileDao(getIt<AppDatabase>()));
  getIt.registerLazySingleton<SessionsDao>(
      () => SessionsDao(getIt<AppDatabase>()));
  getIt.registerLazySingleton<CheckResultsDao>(
      () => CheckResultsDao(getIt<AppDatabase>()));
  getIt.registerLazySingleton<PmcsFaultsDao>(
      () => PmcsFaultsDao(getIt<AppDatabase>()));
  getIt.registerLazySingleton<PmcsReportsDao>(
      () => PmcsReportsDao(getIt<AppDatabase>()));
  getIt.registerLazySingleton<QueuedSubmissionsDao>(
      () => QueuedSubmissionsDao(getIt<AppDatabase>()));

  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepoImpl(getIt<ProfileDao>()),
  );
  getIt.registerLazySingleton<SessionsRepository>(
    () => SessionsRepoImpl(getIt<SessionsDao>()),
  );
  getIt.registerLazySingleton<ResultsRepository>(
    () => ResultsRepoImpl(getIt<CheckResultsDao>()),
  );
  getIt.registerLazySingleton<FaultsRepository>(
    () => FaultsRepoImpl(getIt<PmcsFaultsDao>()),
  );
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepoImpl(getIt<PmcsReportsDao>()),
  );
  getIt.registerLazySingleton<QueuedSubmissionsRepository>(
    () => QueuedSubmissionsRepoImpl(getIt<QueuedSubmissionsDao>()),
  );
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepoImpl(getIt<sdk.LocationService>()),
  );

  getIt.registerLazySingleton<DeliveryCoordinator>(
      () => DeliveryCoordinator(reportsRepository: getIt<ReportsRepository>()),
      dispose: (delivery) => delivery.dispose());
  getIt.registerLazySingleton<Clock>(() => const SystemClock());
  getIt.registerLazySingleton<IdGenerator>(() => UuidIdGenerator());
  getIt.registerLazySingleton<PmcsCatalogSource>(
    () => const StaticPmcsCatalogSource(),
  );
  getIt.registerLazySingleton<FaultClassifierStrategy>(
    () => const TmFaultClassifier(),
  );
  getIt.registerLazySingleton<PmcsReportCodec>(() => const PmcsReportCodec());
  getIt.registerLazySingleton<ReportCodec>(() => getIt<PmcsReportCodec>());
  getIt.registerLazySingleton<PmcsEntityMapper>(
    () => PmcsEntityMapper(codec: getIt<PmcsReportCodec>()),
  );
  getIt.registerLazySingleton<SpeechRecognitionStrategy>(
    () => DeviceSpeechRecognition(),
  );
  getIt.registerLazySingleton<CacScannerStrategy>(
    () => createCacScanner(
      diagnostics: const bool.fromEnvironment('CAC_DIAGNOSTICS')
          ? CacScanDiagnostics()
          : null,
    ),
  );
  getIt.registerFactory<BumperScannerStrategy>(() => createBumperScanner());

  getIt.registerLazySingleton<ReportStoreStrategy>(
    () => createReportStore(extensionContext,
        backend: reportStoreBackend, itemType: reportItemType),
  );
  getIt.registerLazySingleton<PmcsEntityPort>(
      () => getIt<ReportStoreStrategy>());
  getIt.registerLazySingleton<MeshBroadcasterPort>(
    () => SdkMeshBroadcaster(
      messaging: getIt<sdk.MessagingService>(),
      codec: getIt<ReportCodec>(),
    ),
  );
  getIt.registerLazySingleton<RemoteReportSource>(
    () => getIt<ReportStoreStrategy>(),
  );

  getIt.registerLazySingleton<QueueWorkerStrategy>(
    () => createQueueWorker(
      notifications: getIt<UserNotificationSink>(),
      delivery: getIt<DeliveryCoordinator>(),
      repository: getIt<QueuedSubmissionsRepository>(),
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
    ),
  );

  getIt.registerLazySingleton<BuildPhaseFaults>(() => const BuildPhaseFaults());
  getIt.registerLazySingleton<ParseCacBarcode>(
    () => ParseCacBarcode(getIt<Clock>().nowUtc),
  );
  getIt.registerLazySingleton<VerifyOperatorIdentity>(
    () => VerifyOperatorIdentity(
      scanner: getIt<CacScannerStrategy>(),
      parseBarcode: getIt<ParseCacBarcode>(),
    ),
  );
  getIt.registerLazySingleton<StartSession>(
    () => StartSession(
      logger: getIt<DiagnosticLogger>(),
      repository: getIt<SessionsRepository>(),
      locationRepository: getIt<LocationRepository>(),
      clock: getIt<Clock>(),
      idGenerator: getIt<IdGenerator>(),
    ),
  );
  getIt.registerLazySingleton<LoadOpenSessions>(
    () => LoadOpenSessions(getIt<SessionsRepository>()),
  );
  getIt.registerLazySingleton<RecordCheckResult>(
    () => RecordCheckResult(
      repository: getIt<ResultsRepository>(),
      classifier: getIt<FaultClassifierStrategy>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<CompletePhase>(
    () => CompletePhase(
      transactionRunner: getIt<TransactionRunner>(),
      sessionsRepository: getIt<SessionsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
      buildPhaseFaults: getIt<BuildPhaseFaults>(),
    ),
  );
  getIt.registerLazySingleton<AbandonSession>(
    () => AbandonSession(
      transactionRunner: getIt<TransactionRunner>(),
      sessionsRepository: getIt<SessionsRepository>(),
      resultsRepository: getIt<ResultsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
    ),
  );
  getIt.registerLazySingleton<BuildSessionReport>(
    () => BuildSessionReport(getIt<Clock>()),
  );
  getIt.registerLazySingleton<SubmitSession>(
    () => SubmitSession(
      transactionRunner: getIt<TransactionRunner>(),
      sessionsRepository: getIt<SessionsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
      reportsRepository: getIt<ReportsRepository>(),
      buildSessionReport: getIt<BuildSessionReport>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<PublishPmcsReport>(
    () => PublishPmcsReport(
      logger: getIt<DiagnosticLogger>(),
      delivery: getIt<DeliveryCoordinator>(),
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      queueWorker: getIt<QueueWorkerStrategy>(),
      codec: getIt<ReportCodec>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<SubmitMaintainerReview>(
    () => SubmitMaintainerReview(
      reports: getIt<ReportsRepository>(),
      queue: getIt<QueuedSubmissionsRepository>(),
      worker: getIt<QueueWorkerStrategy>(),
      transaction: getIt<TransactionRunner>(),
      codec: getIt<ReportCodec>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<PublishPmcsDeletion>(
    () => PublishPmcsDeletion(
      codec: getIt<ReportCodec>(),
      clock: getIt<Clock>(),
      logger: getIt<DiagnosticLogger>(),
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      queueWorker: getIt<QueueWorkerStrategy>(),
      repository: getIt<ReportsRepository>(),
      delivery: getIt<DeliveryCoordinator>(),
      queuedRepository: getIt<QueuedSubmissionsRepository>(),
      transaction: getIt<TransactionRunner>(),
    ),
  );
  getIt.registerLazySingleton<ParseIncomingReport>(
    () => ParseIncomingReport(getIt<ReportCodec>()),
  );
  getIt.registerLazySingleton<ParseIncomingDeletion>(
    () => ParseIncomingDeletion(getIt<ReportCodec>()),
  );
  getIt.registerLazySingleton<SyncRemoteReports>(
    () => SyncRemoteReports(
      logger: getIt<DiagnosticLogger>(),
      getIt<RemoteReportSource>(),
      getIt<ReportsRepository>(),
    ),
  );
  getIt.registerLazySingleton<SyncLocalReportsToLattice>(
    () => SyncLocalReportsToLattice(
      logger: getIt<DiagnosticLogger>(),
      delivery: getIt<DeliveryCoordinator>(),
      queuedRepository: getIt<QueuedSubmissionsRepository>(),
      getIt<RemoteReportSource>(),
      getIt<PmcsEntityPort>(),
      reportsRepository: getIt<ReportsRepository>(),
      queueWorker: getIt<QueueWorkerStrategy>(),
      codec: getIt<ReportCodec>(),
    ),
  );
  getIt.registerLazySingleton<ShowReportOnMap>(
    () => ShowReportOnMap(getIt<ReportMapPort>(),
        logger: getIt<DiagnosticLogger>()),
  );
  getIt.registerLazySingleton<SuggestPartsForFault>(
    () => const SuggestPartsForFault(commonParts),
  );

  getIt.registerLazySingleton<FaultSuggestionController>(
    () => FaultSuggestionController(getIt<ReportsRepository>(),
        notifications: getIt<UserNotificationSink>()),
    dispose: (controller) => controller.dispose(),
  );
  getIt.registerLazySingleton<HomeViewModel>(() => HomeViewModel());
  getIt.registerFactory<ProfileViewModel>(
    () => ProfileViewModel(getIt<ProfileRepository>(),
        onSaved: (_) => getIt<ReportsViewModel>().loadMyUic()),
  );
  getIt.registerLazySingleton<InspectionViewModel>(
    () => InspectionViewModel(
      reportsRepository: getIt<ReportsRepository>(),
      clock: getIt<Clock>(),
      snackBarService: getIt<UserNotificationSink>(),
      suggestions: getIt<FaultSuggestionController>(),
      catalogSource: getIt<PmcsCatalogSource>(),
      startSession: getIt<StartSession>(),
      loadOpenSessions: getIt<LoadOpenSessions>(),
      recordCheckResult: getIt<RecordCheckResult>(),
      completePhase: getIt<CompletePhase>(),
      abandonSession: getIt<AbandonSession>(),
      submitSession: getIt<SubmitSession>(),
      publishPmcsReport: getIt<PublishPmcsReport>(),
      resultsRepository: getIt<ResultsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
      speechStrategy: getIt<SpeechRecognitionStrategy>(),
      verifyOperatorIdentity: getIt<VerifyOperatorIdentity>(),
      cacScanner: getIt<CacScannerStrategy>(),
      profileRepository: getIt<ProfileRepository>(),
      onReportSubmitted: (report) =>
          getIt<ReportsViewModel>().addOutgoing(report),
    ),
  );

  getIt.registerLazySingleton<ReportsViewModel>(
    () => ReportsViewModel(
      getIt<ReportMessageSource>(),
      getIt<ReportsRepository>(),
      getIt<ParseIncomingReport>(),
      getIt<ParseIncomingDeletion>(),
      getIt<SyncRemoteReports>(),
      getIt<SyncLocalReportsToLattice>(),
      getIt<ShowReportOnMap>(),
      getIt<PublishPmcsDeletion>(),
      getIt<QueueWorkerStrategy>(),
      notificationPort: getIt<PmcsNotificationPort>(),
      snackBarService: getIt<UserNotificationSink>(),
      profileRepository: getIt<ProfileRepository>(),
      queuedRepository: getIt<QueuedSubmissionsRepository>(),
      suggestions: getIt<FaultSuggestionController>(),
      delivery: getIt<DeliveryCoordinator>(),
    ),
  );
  getIt<ReportsViewModel>();
}
