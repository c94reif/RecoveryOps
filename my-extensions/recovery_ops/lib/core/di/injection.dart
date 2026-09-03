import 'package:get_it/get_it.dart';
import 'package:le_sdk/le_sdk.dart'
    as sdk;
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profileDao.dart';
import 'package:recovery_ops/data/dao/queue/queuedRequestsDao.dart';
import 'package:recovery_ops/data/dao/reports/reportsDao.dart';
import 'package:recovery_ops/data/repositories/profileRepoImpl.dart';
import 'package:recovery_ops/data/repositories/queuedRequestsRepoImpl.dart';
import 'package:recovery_ops/data/repositories/reportsRepoImpl.dart';
import 'package:recovery_ops/data/repositories/locationRepoImpl.dart';
import 'package:recovery_ops/data/services/deviceSpeechRecognition.dart';
import 'package:recovery_ops/data/services/isolateQueueWorker.dart';
import 'package:recovery_ops/data/services/latticeEntityAdapter.dart';
import 'package:recovery_ops/data/services/latticeReportSource.dart';
import 'package:recovery_ops/data/services/regexTranscriptParsetr.dart';
import 'package:recovery_ops/data/services/sdkMeshBroadcaster.dart';
import 'package:recovery_ops/domain/repositories/profileRepo.dart';
import 'package:recovery_ops/domain/repositories/queuedRequestsRepo.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';
import 'package:recovery_ops/domain/services/queuePromptStrategy.dart';
import 'package:recovery_ops/domain/services/queueWorkerStrategy.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';
import 'package:recovery_ops/domain/services/speechRecognitionStrategy.dart';
import 'package:recovery_ops/domain/services/transcriptParserStrategy.dart';
import 'package:recovery_ops/presentation/common/services/queuePromptController.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcastNavigatorLocation.dart';
import 'package:recovery_ops/domain/usecases/navigation/navigateToReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';
import 'package:recovery_ops/domain/usecases/navigation/pollRouteGeometry.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigationStopped.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigatorEntity.dart';
import 'package:recovery_ops/domain/usecases/navigation/syncNavigatorStates.dart';
import 'package:recovery_ops/domain/usecases/navigation/viewReportOnMap.dart';
import 'package:recovery_ops/domain/usecases/recovery/publishRecoveryDeletion.dart';
import 'package:recovery_ops/domain/usecases/recovery/publishRecoveryRequest.dart';
import 'package:recovery_ops/domain/usecases/reporting/parseIncomingDeletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parseIncomingReport.dart';
import 'package:recovery_ops/domain/usecases/reporting/submitOutgoingReport.dart';
import 'package:recovery_ops/domain/usecases/reporting/syncLocalReportsToLattice.dart';
import 'package:recovery_ops/domain/usecases/reporting/syncRemoteReports.dart';
import 'package:recovery_ops/presentation/profile/profileViewModel.dart';
import 'package:recovery_ops/presentation/home/homeViewModel.dart';
import 'package:recovery_ops/presentation/recovery/recoveryViewModel.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';

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
