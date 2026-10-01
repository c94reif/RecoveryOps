import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/dao/queue/queued_submissions_dao.dart';
import 'package:circle_x/data/dao/reports/pmcs_reports_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/repositories/queued_submissions_repo_impl.dart';
import 'package:circle_x/data/repositories/reports_repo_impl.dart';
import 'package:circle_x/data/services/drift_transaction_runner.dart';
import 'package:circle_x/data/services/main_thread_queue_worker.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/data/services/sdk_mesh_broadcaster.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_deletion.dart';
import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import 'main_thread_queue_worker_test.dart' show FakeQueuePromptStrategy;
import 'sdk_mesh_broadcaster_test.dart' show FakeMessagingService;

void main() {
  late AppDatabase db;
  late ReportsRepoImpl reports;
  late QueuedSubmissionsRepoImpl queue;
  late DeliveryCoordinator delivery;
  late FakeMeshItems items;
  late FakeMessagingService messaging;
  late MeshItemReportStoreStrategy store;
  late SdkMeshBroadcaster peers;
  late MainThreadQueueWorker worker;
  const codec = PmcsReportCodec();

  void connectWorker() {
    delivery = DeliveryCoordinator(reportsRepository: reports);
    store = MeshItemReportStoreStrategy(items: items);
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: peers,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery);
  }

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    reports = ReportsRepoImpl(PmcsReportsDao(db));
    queue = QueuedSubmissionsRepoImpl(QueuedSubmissionsDao(db));
    items = FakeMeshItems()..failWrites = true;
    messaging = FakeMessagingService()..results = [];
    peers = SdkMeshBroadcaster(messaging: messaging);
    connectWorker();
  });

  tearDown(() async {
    await worker.stop();
    await Future<void>.delayed(Duration.zero);
    await delivery.dispose();
    await db.close();
  });

  test('database and both outbox legs survive worker restart with item storage',
      () async {
    final report = await reports.insertReport(buildReport(
        signature: buildSignature(), faults: [buildFault(note: 'oil leak')]));
    final publish = PublishPmcsReport(
        entityPort: store,
        meshPort: peers,
        queueWorker: worker,
        codec: codec,
        clock: const SystemClock(),
        delivery: delivery);
    expect((await publish(report)).allFailed, isTrue);
    expect(await queue.count(), 2);
    expect(await reports.getAllReports(), hasLength(1));

    await worker.stop();
    await delivery.dispose();
    connectWorker();
    items.failWrites = false;
    messaging.results = [
      const sdk.DeliveryResult(peerId: 'peer', success: true)
    ];
    await worker.start();
    await worker.onProbeTick();
    expect(await queue.count(), 0);
    expect(await reports.getAllReports(), hasLength(1));
    final remote = (await store.fetchRemotePmcsReports()).single;
    expect(codec.reportBody(remote), codec.reportBody(report));
    expect(messaging.broadcasts.last, codec.encodeReport(report));
  });

  test(
      'offline withdrawals retain durable queue and retry to both destinations',
      () async {
    final report = await reports.insertReport(buildReport());
    items.failWrites = false;
    await store.publishPmcsReport(report);
    items.failWrites = true;
    final withdraw = PublishPmcsDeletion(
        codec: codec,
        entityPort: store,
        meshPort: peers,
        queueWorker: worker,
        repository: reports,
        delivery: delivery,
        queuedRepository: queue,
        transaction: DriftTransactionRunner(db));
    expect((await withdraw(report)).allFailed, isTrue);
    expect(await queue.count(), 2);
    expect(await reports.getWithdrawnIds(), {report.entityId});
    expect(await reports.getAllReports(), isEmpty);

    await worker.stop();
    await delivery.dispose();
    connectWorker();
    items.failWrites = false;
    messaging.results = [
      const sdk.DeliveryResult(peerId: 'peer', success: true)
    ];
    await worker.start();
    await worker.onProbeTick();
    expect(await queue.count(), 0);
    expect(await store.fetchWithdrawnPmcsEntityIds(), {report.entityId});
    expect(await store.fetchRemotePmcsReports(), isEmpty);
    expect(messaging.broadcasts.last, codec.encodeDeletion(report.entityId));
  });
}
