import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/dao/queue/queued_requests_dao.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/services/isolate_queue_worker.dart';
import 'package:recovery_ops/data/services/mesh_item_report_store_strategy.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';
import 'package:recovery_ops/domain/repositories/location_repo.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/domain/repositories/queued_requests_repo.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';
import 'package:recovery_ops/domain/services/queue_worker_strategy.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/speech_recognition_strategy.dart';
import 'package:recovery_ops/domain/services/transcript_parser_strategy.dart';
import 'package:recovery_ops/presentation/common/services/queue_prompt_controller.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';
import 'package:recovery_ops/presentation/recovery/recovery_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';

import 'support/queued_request_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late sdk.StubExtensionContext context;
  late ReportsViewModel reports;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase.test(NativeDatabase.memory());
    // Replace only the device database boundary; build the real service graph.
    getIt.registerSingleton<AppDatabase>(db);
    getIt.skipDoubleRegistration = true;
    context = sdk.StubExtensionContext();
    configureDependencies(context);
    getIt.skipDoubleRegistration = false;
    reports = getIt<ReportsViewModel>();
    // Wait for the constructor's initial database read before teardown.
    await reports.loadFromDb();
  });

  tearDown(() async {
    reports.dispose();
    getIt<NavigationViewModel>().dispose();
    if (getIt.isRegistered<QueueWorkerStrategy>()) {
      await getIt<QueueWorkerStrategy>().stop();
    }
    await getIt.reset();
    getIt.skipDoubleRegistration = false;
    await db.close();
    context.close();
  });

  test('host services resolve to the supplied extension context', () {
    expect(getIt<sdk.ExtensionContext>(), same(context));
    expect(getIt<sdk.LocationService>(), same(context.location));
    expect(getIt<sdk.MapService>(), same(context.map));
    expect(getIt<sdk.SpeechService>(), same(context.speech));
    expect(getIt<sdk.StorageService>(), same(context.storage));
    expect(getIt<sdk.MessagingService>(), same(context.messaging));
    expect(getIt<sdk.EntityService>(), same(context.entities));
    expect(reports.messaging, same(context.messaging));
    expect(reports.mapService, same(context.map));
    expect(reports.repository, same(getIt<ReportsRepository>()));
    expect(reports.navigationViewModel, same(getIt<NavigationViewModel>()));
  });

  test('default remote read and write ports share the mesh item strategy', () {
    final store = getIt<ReportStoreStrategy>();
    expect(store, isA<MeshItemReportStoreStrategy>());
    expect(getIt<RecoveryEntityPort>(), same(store));
    expect(getIt<RemoteReportSource>(), same(store));
  });

  test(
      'repositories and DAOs share one database and persist across view models',
      () async {
    expect(getIt<AppDatabase>(), same(db));
    expect(getIt<ProfileDao>().attachedDatabase, same(db));
    expect(getIt<ReportsDao>().attachedDatabase, same(db));
    expect(getIt<QueuedRequestsDao>().attachedDatabase, same(db));
    final first = getIt<ProfileViewModel>();
    final second = getIt<ProfileViewModel>();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(first, isNot(same(second)));
    expect(first.repository, same(getIt<ProfileRepository>()));
    expect(second.repository, same(first.repository));

    await first.save('Alex', 'Eagle', 'HQ');
    await second.loadProfile();
    expect(second.savedName, 'Alex');
    expect(second.savedCallSign, 'Eagle');
    expect(second.savedUnit, 'HQ');
    expect(second.hasExistingProfile, isTrue);
  });

  test('recovery screens receive shared delivery and report services', () {
    final first = getIt<RecoveryViewModel>();
    final second = getIt<RecoveryViewModel>();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(first, isNot(same(second)));
    expect(first.reportsViewModel, same(reports));
    expect(second.reportsViewModel, same(reports));
    expect(first.speechStrategy, same(getIt<SpeechRecognitionStrategy>()));
    expect(first.parserStrategy, same(getIt<TranscriptParserStrategy>()));
    expect(first.mapService, same(context.map));
    expect(getIt<ReportsViewModel>(), same(reports));
  });

  test('home uses the host location through the registered repository',
      () async {
    final home = getIt<HomeViewModel>();
    addTearDown(home.dispose);
    expect(home.locationRepository, same(getIt<LocationRepository>()));
    final location = await home.getInitialLocation();
    final hostLocation = await context.location.getCurrentLocation();
    expect(location!.latitude, hostLocation!.latitude);
    expect(location.longitude, hostLocation.longitude);
  });

  test('queue worker is wired to durable storage and both delivery transports',
      () async {
    final worker = getIt<QueueWorkerStrategy>() as IsolateQueueWorker;
    expect(getIt<QueueWorkerStrategy>(), same(worker));
    expect(worker.repository, same(getIt<QueuedRequestsRepository>()));
    expect(worker.entityPort, same(getIt<RecoveryEntityPort>()));
    expect(worker.meshPort, same(getIt<MeshBroadcasterPort>()));
    expect(worker.promptStrategy, same(getIt<QueuePromptStrategy>()));
    expect(worker.promptStrategy, same(QueuePromptController.instance));
    final stored = await worker.repository.insert(queuedRequest());
    expect((await worker.repository.getAll()).single.toMap(), stored.toMap());
  });
}
