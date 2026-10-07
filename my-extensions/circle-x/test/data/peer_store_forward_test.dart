import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/dao/queue/queued_submissions_dao.dart';
import 'package:circle_x/data/dao/reports/pmcs_reports_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/repositories/queued_submissions_repo_impl.dart';
import 'package:circle_x/data/repositories/reports_repo_impl.dart';
import 'package:circle_x/data/services/main_thread_queue_worker.dart';
import 'package:circle_x/data/services/isolate_queue_worker.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/mileage_reading.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/usecases/reporting/store_received_report.dart';
import 'package:circle_x/domain/usecases/reporting/sync_local_reports_to_lattice.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import '../support/report_schema.dart';

void main() {
  const codec = PmcsReportCodec();
  late AppDatabase db;
  late ReportsRepoImpl reports;
  late QueuedSubmissionsRepoImpl queue;
  late FakeMeshItems items;
  late MeshItemReportStoreStrategy store;
  late DeliveryCoordinator delivery;
  late MainThreadQueueWorker worker;
  late FakeMeshBroadcaster mesh;
  final review = buildReport(
    entityId: 'review',
    isOutgoing: false,
    isRead: false,
    fromCallsign: 'Peer ALPHA',
    faults: [buildFault(itemId: 'engine')],
    mileage: MileageReading(value: 123456.7, unit: MileageUnit.miles),
    signature: buildSignature(),
    maintainerReview: MaintainerReview(
      sourceReportId: 'original',
      faults: const [
        FaultReview(itemId: 'engine', phase: PmcsPhase.before, verified: true),
      ],
      signature: buildSignature(),
    ),
  );

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    reports = ReportsRepoImpl(PmcsReportsDao(db));
    queue = QueuedSubmissionsRepoImpl(QueuedSubmissionsDao(db));
    items = FakeMeshItems(validate: validateReportRecord);
    store = MeshItemReportStoreStrategy(items: items);
    mesh = FakeMeshBroadcaster();
    delivery = DeliveryCoordinator(reportsRepository: reports);
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: mesh,
        delivery: delivery);
  });
  tearDown(() async {
    await worker.stop();
    await Future<void>.delayed(Duration.zero);
    await delivery.dispose();
    await db.close();
  });

  SyncLocalReportsToLattice relay() => SyncLocalReportsToLattice(
        store,
        store,
        reportsRepository: reports,
        queuedRepository: queue,
        delivery: delivery,
        queueWorker: worker,
        codec: codec,
      );

  test('offline incoming review restores its PMCS and forwards after restart',
      () async {
    await storeReceivedReport(reports, review);
    items.failList = true;
    expect(await relay()(await reports.getAllReports()), 0);
    expect(items.created, isEmpty);
    expect(await reports.getAllReports(), hasLength(2));

    // Rebuild the reconciliation object from durable rows, without a new peer
    // message or a new operator submission to trigger the original report.
    items.failList = false;
    expect(await relay()(await reports.getAllReports()), 2);
    final remote = await store.fetchRemotePmcsReports();
    expect(remote.map((report) => report.entityId).toSet(),
        {'original', 'review'});
    expect(remote.every((report) => report.mileage!.value == 123456.7), isTrue);
    expect(
        remote
            .singleWhere((report) => report.isMaintainerReview)
            .maintainerReview!
            .signature
            .toMap(),
        review.maintainerReview!.signature.toMap());
    expect(
        (await reports.getAllReports()).every((report) => !report.isOutgoing),
        isTrue);
    expect(mesh.broadcast, isEmpty);
    expect(mesh.broadcastPayloads, isEmpty);

    final anotherPeer = FakeReportsRepository();
    await storeReceivedReport(anotherPeer, review);
    expect(
        await SyncLocalReportsToLattice(store, store,
            reportsRepository: anotherPeer)(await anotherPeer.getAllReports()),
        0);
    expect(items.created, hasLength(2));
    expect(items.updated, isEmpty);
  });

  test('failed relays persist to SQLite and retry through the queue', () async {
    await storeReceivedReport(reports, review);
    items.failWrites = true;
    expect(await relay()(await reports.getAllReports()), 0);
    expect(await queue.count(), 2);
    expect(
        (await queue.getAll())
            .every((row) => row.transport.wireName == 'lattice'),
        isTrue);
    await worker.stop();
    await delivery.dispose();
    delivery = DeliveryCoordinator(reportsRepository: reports);
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: mesh,
        delivery: delivery);
    items.failWrites = false;
    await worker.start();
    await worker.retryNow();
    expect(await queue.count(), 0);
    expect(await store.fetchKnownPmcsEntityIds(), {'original', 'review'});
    expect(mesh.broadcastPayloads, isEmpty);
  });

  test('peer withdrawals survive disconnection and dominate a stale peer',
      () async {
    await storeReceivedReport(reports, review);
    final stalePeer = FakeReportsRepository();
    await storeReceivedReport(stalePeer, review);
    await reports.withdrawReport('original');
    items.failList = true;
    expect(await relay()(await reports.getAllReports()), 0);
    items.failList = false;
    expect(await relay()(await reports.getAllReports()), 1);
    expect(await store.fetchWithdrawnPmcsEntityIds(), {'original'});
    expect(await store.fetchRemotePmcsReports(), isEmpty);
    expect(
        await SyncLocalReportsToLattice(store, store,
            reportsRepository: stalePeer)(await stalePeer.getAllReports()),
        0);
    expect(await stalePeer.getWithdrawnIds(), {'original'});
    expect(items.created, hasLength(1));
    expect(items.updated, isEmpty);
  });

  for (final native in [false, true]) {
    test(
        '${native ? 'native' : 'web'} queued review respects a remote source withdrawal before local sync',
        () async {
      await storeReceivedReport(reports, review);
      await queue.insert(buildQueuedSubmission(
          entityId: review.entityId, payload: codec.encodeReport(review)));
      // Another device withdrew the original while this device was offline.
      await store.deletePmcsEntity('original');
      expect(await reports.getWithdrawnIds(), isEmpty);
      final QueueWorkerStrategy resumed = native
          ? IsolateQueueWorker(
              repository: queue,
              entityPort: store,
              meshPort: mesh,
              delivery: delivery)
          : worker;
      addTearDown(resumed.stop);
      final settled = Completer<void>();
      final subscription = delivery.changes.listen((_) async {
        if (await queue.count() == 0 && !settled.isCompleted) {
          settled.complete();
        }
      });
      addTearDown(subscription.cancel);
      await resumed.start();
      await resumed.retryNow();
      await settled.future.timeout(const Duration(seconds: 3));
      expect(await queue.count(), 0);
      expect(await store.fetchRemotePmcsReports(), isEmpty);
      expect(await store.fetchWithdrawnPmcsEntityIds(), {'original'});
      expect(await reports.getWithdrawnIds(), isEmpty);
      expect(items.created, hasLength(1));
      expect(items.updated, isEmpty);
      expect(mesh.broadcastPayloads, isEmpty);
    });
  }
}
