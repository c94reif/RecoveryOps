import 'package:get_it/get_it.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/dao/queue/queued_requests_dao.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';
import 'package:recovery_ops/data/repositories/profile_repo_impl.dart';
import 'package:recovery_ops/data/repositories/queued_requests_repo_impl.dart';
import 'package:recovery_ops/data/repositories/reports_repo_impl.dart';
import 'package:recovery_ops/data/repositories/location_repo_impl.dart';
import 'package:recovery_ops/data/services/device_speech_recognition.dart';
import 'package:recovery_ops/data/services/isolate_queue_worker.dart';
import 'package:recovery_ops/data/services/lattice_entity_adapter.dart';
import 'package:recovery_ops/data/services/lattice_report_source.dart';
import 'package:recovery_ops/data/services/regex_transcript_parsetr.dart';
import 'package:recovery_ops/data/services/sdk_mesh_broadcaster.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/domain/repositories/queued_requests_repo.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/repositories/location_repo.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';
import 'package:recovery_ops/domain/services/queue_worker_strategy.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/services/speech_recognition_strategy.dart';
import 'package:recovery_ops/domain/services/transcript_parser_strategy.dart';
import 'package:recovery_ops/presentation/common/services/queue_prompt_controller.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcast_navigator_location.dart';
import 'package:recovery_ops/domain/usecases/navigation/navigate_to_report.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/navigation/poll_route_geometry.dart';
import 'package:recovery_ops/domain/usecases/navigation/publish_navigation_stopped.dart';
import 'package:recovery_ops/domain/usecases/navigation/publish_navigator_entity.dart';
import 'package:recovery_ops/domain/usecases/navigation/sync_navigator_states.dart';
import 'package:recovery_ops/domain/usecases/navigation/view_report_on_map.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_deletion.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_request.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:recovery_ops/domain/usecases/reporting/submit_outgoing_report.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/recovery/recovery_view_model.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';

final getIt = GetIt.instance;

void configureDependencies(sdk.ExtensionContext extensionContext) {
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
  getIt.registerLazySingleton<ProfileDao>(
    () => ProfileDao(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<ReportsDao>(
    () => ReportsDao(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<QueuedRequestsDao>(
    () => QueuedRequestsDao(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepoImpl(getIt<ProfileDao>()),
  );
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepoImpl(getIt<ReportsDao>()),
  );
  getIt.registerLazySingleton<QueuedRequestsRepository>(
    () => QueuedRequestsRepoImpl(getIt<QueuedRequestsDao>()),
  );
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepoImpl(getIt<sdk.LocationService>()),
  );

  getIt.registerLazySingleton<QueuePromptStrategy>(
    () => QueuePromptController.instance,
  );

  getIt.registerLazySingleton<SpeechRecognitionStrategy>(
    () => DeviceSpeechRecognition(),
  );

  getIt.registerLazySingleton<TranscriptParserStrategy>(
    () => RegexTranscriptParser(),
  );

  getIt.registerLazySingleton<RecoveryEntityPort>(
    () => LatticeEntityAdapter(entities: getIt<sdk.EntityService>()),
  );
  getIt.registerLazySingleton<MeshBroadcasterPort>(
    () => SdkMeshBroadcaster(messaging: getIt<sdk.MessagingService>()),
  );
  getIt.registerLazySingleton<RemoteReportSource>(
    () => LatticeReportSource(entities: getIt<sdk.EntityService>()),
  );

  getIt.registerLazySingleton<QueueWorkerStrategy>(
    () => IsolateQueueWorker(
      repository: getIt<QueuedRequestsRepository>(),
      entityPort: getIt<RecoveryEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      promptStrategy: getIt<QueuePromptStrategy>(),
    ),
  );

  getIt.registerLazySingleton<PublishRecoveryRequest>(
    () => PublishRecoveryRequest(
      entityPort: getIt<RecoveryEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
      queueWorker: getIt<QueueWorkerStrategy>(),
    ),
  );
  getIt.registerLazySingleton<PublishRecoveryDeletion>(
    () => PublishRecoveryDeletion(
      entityPort: getIt<RecoveryEntityPort>(),
      meshPort: getIt<MeshBroadcasterPort>(),
    ),
  );
  getIt.registerLazySingleton<BroadcastNavigatorLocation>(
    () => BroadcastNavigatorLocation(getIt<MeshBroadcasterPort>()),
  );
  getIt.registerLazySingleton<PublishNavigatorEntity>(
    () => PublishNavigatorEntity(getIt<RecoveryEntityPort>()),
  );
  getIt.registerLazySingleton<PublishNavigationStopped>(
    () => PublishNavigationStopped(getIt<MeshBroadcasterPort>()),
  );

  getIt.registerFactory<ProfileViewModel>(
    () => ProfileViewModel(getIt<ProfileRepository>()),
  );
  getIt.registerFactory<HomeViewModel>(
    () => HomeViewModel(
      getIt<LocationRepository>(),
    ),
  );

  getIt.registerFactory<RecoveryViewModel>(
    () => RecoveryViewModel(
      getIt<SpeechRecognitionStrategy>(),
      getIt<TranscriptParserStrategy>(),
      submitOutgoingReport: getIt<SubmitOutgoingReport>(),
      mapService: getIt<sdk.MapService>(),
      publishRecoveryRequest: getIt<PublishRecoveryRequest>(),
      reportsViewModel: getIt<ReportsViewModel>(),
    ),
  );

  getIt.registerLazySingleton<ParseIncomingReport>(
    () => ParseIncomingReport(),
  );
  getIt.registerLazySingleton<ParseIncomingDeletion>(
    () => ParseIncomingDeletion(),
  );
  getIt.registerLazySingleton<SubmitOutgoingReport>(
    () => SubmitOutgoingReport(getIt<ReportsRepository>()),
  );
  getIt.registerLazySingleton<ViewReportOnMap>(
    () => ViewReportOnMap(getIt<sdk.MapService>()),
  );
  getIt.registerLazySingleton<NavigateToReport>(
    () => NavigateToReport(
      getIt<sdk.MapService>(),
      getIt<ReportsRepository>(),
      getIt<BroadcastNavigatorLocation>(),
      getIt<PublishNavigatorEntity>(),
    ),
  );
  getIt.registerLazySingleton<ParseNavigatorUpdate>(
    () => ParseNavigatorUpdate(),
  );
  getIt.registerLazySingleton<PollRouteGeometry>(
    () => PollRouteGeometry(
      getIt<RemoteReportSource>(),
      getIt<ReportsRepository>(),
    ),
  );
  getIt.registerLazySingleton<SyncRemoteReports>(
    () => SyncRemoteReports(
      getIt<RemoteReportSource>(),
      getIt<ReportsRepository>(),
    ),
  );
  getIt.registerLazySingleton<SyncLocalReportsToLattice>(
    () => SyncLocalReportsToLattice(
      getIt<RemoteReportSource>(),
      getIt<RecoveryEntityPort>(),
    ),
  );
  getIt.registerLazySingleton<SyncNavigatorStates>(
    () => SyncNavigatorStates(getIt<RemoteReportSource>()),
  );

  getIt.registerLazySingleton<NavigationViewModel>(
    () => NavigationViewModel(
      getIt<sdk.LocationService>(),
      getIt<NavigateToReport>(),
      getIt<BroadcastNavigatorLocation>(),
      getIt<PublishNavigatorEntity>(),
      getIt<PublishNavigationStopped>(),
    ),
  );

  getIt.registerLazySingleton<ReportsViewModel>(
    () => ReportsViewModel(
      getIt<sdk.MessagingService>(),
      getIt<ReportsRepository>(),
      getIt<ParseIncomingReport>(),
      getIt<ParseIncomingDeletion>(),
      getIt<ViewReportOnMap>(),
      getIt<ParseNavigatorUpdate>(),
      getIt<PollRouteGeometry>(),
      getIt<SyncRemoteReports>(),
      getIt<SyncLocalReportsToLattice>(),
      getIt<SyncNavigatorStates>(),
      getIt<sdk.MapService>(),
      getIt<NavigationViewModel>(),
      getIt<PublishRecoveryDeletion>(),
    ),
  );
  getIt<ReportsViewModel>();
}
