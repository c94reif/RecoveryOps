import 'package:get_it/get_it.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;

import 'package:ivy_pulse/data/catalog/pmcs_reference_data.g.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/mappers/pmcs_entity_mapper.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/data/repositories/faults_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/location_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/profile_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/queued_submissions_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/reports_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/results_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/sessions_repo_impl.dart';
import 'package:ivy_pulse/data/services/cac_scanner_factory.dart';
import 'package:ivy_pulse/data/services/device_speech_recognition.dart';
import 'package:ivy_pulse/data/services/drift_transaction_runner.dart';
import 'package:ivy_pulse/data/services/lattice_pmcs_adapter.dart';
import 'package:ivy_pulse/data/services/lattice_report_source.dart';
import 'package:ivy_pulse/data/services/queue_worker_factory.dart';
import 'package:ivy_pulse/data/services/sdk_mesh_broadcaster.dart';
import 'package:ivy_pulse/data/services/static_pmcs_catalog_source.dart';
import 'package:ivy_pulse/data/services/system_id_generator.dart';
import 'package:ivy_pulse/data/services/tm_fault_classifier.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/location_repo.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/domain/services/id_generator.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';
import 'package:ivy_pulse/domain/usecases/faults/build_phase_faults.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';
import 'package:ivy_pulse/domain/usecases/map/show_report_on_map.dart';
import 'package:ivy_pulse/domain/usecases/parts/suggest_parts_for_fault.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:ivy_pulse/domain/usecases/session/abandon_session.dart';
import 'package:ivy_pulse/domain/usecases/session/complete_phase.dart';
import 'package:ivy_pulse/domain/usecases/session/load_open_sessions.dart';
import 'package:ivy_pulse/domain/usecases/session/record_check_result.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';
import 'package:ivy_pulse/presentation/common/services/queue_prompt_controller.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

final getIt = GetIt.instance;

void configureDependencies(sdk.ExtensionContext extensionContext) {
  // ── Host services ────────────────────────────────────────────────────
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

  // ── Database, DAOs, repositories ─────────────────────────────────────
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
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

  // ── Domain-facing services ───────────────────────────────────────────
  getIt.registerLazySingleton<DeliveryCoordinator>(() => DeliveryCoordinator(),
      dispose: (delivery) => delivery.dispose());
  getIt.registerLazySingleton<Clock>(() => const SystemClock());
  getIt.registerLazySingleton<IdGenerator>(() => UuidIdGenerator());
  getIt.registerLazySingleton<PmcsCatalogSource>(
    () => const StaticPmcsCatalogSource(),
  );
  getIt.registerLazySingleton<FaultClassifierStrategy>(
    () => const TmFaultClassifier(),
  );
  // The entity mapper is the one collaborator that needs the concrete codec:
  // it reuses the codec's body shape so the Lattice description and the mesh
  // payload can never drift apart. Everything else depends on the port.
  getIt.registerLazySingleton<PmcsReportCodec>(() => const PmcsReportCodec());
  getIt.registerLazySingleton<ReportCodec>(() => getIt<PmcsReportCodec>());
  getIt.registerLazySingleton<PmcsEntityMapper>(
    () => PmcsEntityMapper(codec: getIt<PmcsReportCodec>()),
  );
  getIt.registerLazySingleton<SpeechRecognitionStrategy>(
    () => DeviceSpeechRecognition(),
  );
  // Camera on the web build, a refusal everywhere else — the same shape the
  // queue worker uses to pick an implementation the platform can run.
  getIt.registerLazySingleton<CacScannerStrategy>(() => createCacScanner());
  getIt.registerLazySingleton<QueuePromptStrategy>(
    () => QueuePromptController.instance,
  );

  getIt.registerLazySingleton<PmcsEntityPort>(
    () => LatticePmcsAdapter(
      entities: getIt<sdk.EntityService>(),
      mapper: getIt<PmcsEntityMapper>(),
    ),
  );
  getIt.registerLazySingleton<MeshBroadcasterPort>(
    () => SdkMeshBroadcaster(
      messaging: getIt<sdk.MessagingService>(),
      codec: getIt<ReportCodec>(),
    ),
  );
  getIt.registerLazySingleton<RemoteReportSource>(
    () => LatticeReportSource(
      entities: getIt<sdk.EntityService>(),
      entityMapper: getIt<PmcsEntityMapper>(),
    ),
  );

  // The queue worker runs off the UI thread where the platform allows it, so a
  // long backlog never stutters a walk-around.
  getIt.registerLazySingleton<QueueWorkerStrategy>(
    () => createQueueWorker(
      delivery: getIt<DeliveryCoordinator>(),
      repository: getIt<QueuedSubmissionsRepository>(),
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      promptStrategy: getIt<QueuePromptStrategy>(),
    ),
  );

  // ── Use cases ────────────────────────────────────────────────────────
  getIt.registerLazySingleton<BuildPhaseFaults>(() => const BuildPhaseFaults());
  getIt.registerLazySingleton<ParseCacBarcode>(
    () => ParseCacBarcode(getIt<Clock>()),
  );
  getIt.registerLazySingleton<VerifyOperatorIdentity>(
    () => VerifyOperatorIdentity(
      scanner: getIt<CacScannerStrategy>(),
      parseBarcode: getIt<ParseCacBarcode>(),
    ),
  );
  getIt.registerLazySingleton<StartSession>(
    () => StartSession(
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
      sessionsRepository: getIt<SessionsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
      buildPhaseFaults: getIt<BuildPhaseFaults>(),
    ),
  );
  getIt.registerLazySingleton<AbandonSession>(
    () => AbandonSession(
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
      transactionRunner: DriftTransactionRunner(getIt<AppDatabase>()),
      sessionsRepository: getIt<SessionsRepository>(),
      faultsRepository: getIt<FaultsRepository>(),
      reportsRepository: getIt<ReportsRepository>(),
      buildSessionReport: getIt<BuildSessionReport>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<PublishPmcsReport>(
    () => PublishPmcsReport(
      delivery: getIt<DeliveryCoordinator>(),
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      queueWorker: getIt<QueueWorkerStrategy>(),
      codec: getIt<ReportCodec>(),
      clock: getIt<Clock>(),
    ),
  );
  getIt.registerLazySingleton<PublishPmcsDeletion>(
    () => PublishPmcsDeletion(
      entityPort: getIt<PmcsEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
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
      getIt<RemoteReportSource>(),
      getIt<ReportsRepository>(),
    ),
  );
  getIt.registerLazySingleton<SyncLocalReportsToLattice>(
    () => SyncLocalReportsToLattice(
      delivery: getIt<DeliveryCoordinator>(),
      queuedRepository: getIt<QueuedSubmissionsRepository>(),
      getIt<RemoteReportSource>(),
      getIt<PmcsEntityPort>(),
    ),
  );
  getIt.registerLazySingleton<ShowReportOnMap>(
    () => ShowReportOnMap(getIt<sdk.MapService>()),
  );
  getIt.registerLazySingleton<SuggestPartsForFault>(
    () => const SuggestPartsForFault(commonParts),
  );

  // ── View models ──────────────────────────────────────────────────────
  getIt.registerLazySingleton<HomeViewModel>(() => HomeViewModel());
  getIt.registerFactory<ProfileViewModel>(
    () => ProfileViewModel(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<InspectionViewModel>(
    () => InspectionViewModel(
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
      // Resolved at call time, not here: the reports screen is registered
      // below, and a submitted PMCS has to land on its YOURS tab at once.
      onReportSubmitted: (report) =>
          getIt<ReportsViewModel>().addOutgoing(report),
    ),
  );

  // Eagerly built: it must be listening to the mesh before the operator opens
  // the Reports tab, or inbound PMCS from other crews is missed.
  getIt.registerLazySingleton<ReportsViewModel>(
    () => ReportsViewModel(
      getIt<sdk.MessagingService>(),
      getIt<ReportsRepository>(),
      getIt<ParseIncomingReport>(),
      getIt<ParseIncomingDeletion>(),
      getIt<SyncRemoteReports>(),
      getIt<SyncLocalReportsToLattice>(),
      getIt<ShowReportOnMap>(),
      getIt<PublishPmcsDeletion>(),
      getIt<QueueWorkerStrategy>(),
      profileRepository: getIt<ProfileRepository>(),
      queuedRepository: getIt<QueuedSubmissionsRepository>(),
      delivery: getIt<DeliveryCoordinator>(),
    ),
  );
  getIt<ReportsViewModel>();
}
