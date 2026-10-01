import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/dao/queue/queued_submissions_dao.dart';
import 'package:circle_x/data/dao/reports/pmcs_reports_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/repositories/queued_submissions_repo_impl.dart';
import 'package:circle_x/data/repositories/reports_repo_impl.dart';
import 'package:circle_x/data/services/drift_transaction_runner.dart';
import 'package:circle_x/data/services/main_thread_queue_worker.dart';
import 'package:circle_x/data/services/isolate_queue_worker.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/domain/usecases/reporting/sync_remote_reports.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import 'main_thread_queue_worker_test.dart' show FakeQueuePromptStrategy;

class FailingReviewQueue extends QueuedSubmissionsRepoImpl {
  FailingReviewQueue(super.dao);
  @override
  Future<QueuedSubmission> insert(QueuedSubmission submission) async {
    final stored = await super.insert(submission);
    if (submission.transport == TransportKind.mesh) {
      throw StateError('disk full');
    }
    return stored;
  }
}

void main() {
  late AppDatabase database;
  late ReportsRepoImpl reports;
  late QueuedSubmissionsRepoImpl queue;
  late FakeMeshItems items;
  late MeshItemReportStoreStrategy store;
  late FakeMeshBroadcaster peers;
  late DeliveryCoordinator delivery;
  late MainThreadQueueWorker worker;
  const codec = PmcsReportCodec();
  const decisions = [
    FaultReview(
        itemId: 'engine',
        phase: PmcsPhase.before,
        verified: true,
        description: 'Leak confirmed.'),
    FaultReview(
        itemId: 'brakes',
        phase: PmcsPhase.before,
        verified: false,
        description: 'Could not reproduce.'),
  ];

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    reports = ReportsRepoImpl(PmcsReportsDao(database));
    queue = QueuedSubmissionsRepoImpl(QueuedSubmissionsDao(database));
    items = FakeMeshItems();
    store = MeshItemReportStoreStrategy(items: items);
    peers = FakeMeshBroadcaster();
    delivery = DeliveryCoordinator(reportsRepository: reports);
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: peers,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery);
    await reports.insertReport(buildReport(
      entityId: 'original',
      signature: buildSignature(),
      faults: [
        buildFault(itemId: 'engine', note: 'Original operator note'),
        buildFault(itemId: 'brakes')
      ],
    ));
  });

  tearDown(() async {
    await worker.stop();
    await delivery.dispose();
    await database.close();
  });

  SubmitMaintainerReview submit({QueuedSubmissionsRepoImpl? withQueue}) =>
      SubmitMaintainerReview(
        reports: reports,
        queue: withQueue ?? queue,
        worker: worker,
        transaction: DriftTransactionRunner(database),
        codec: codec,
        clock: FixedClock(DateTime.utc(2026, 9, 30)),
      );

  PublishPmcsReport publisher() => PublishPmcsReport(
      entityPort: store,
      meshPort: peers,
      queueWorker: worker,
      codec: codec,
      clock: FixedClock(DateTime.utc(2026, 9, 30)),
      delivery: delivery);

  test('signed batch persists separately and reaches both mesh store and peers',
      () async {
    final original = (await reports.getAllReports()).single;
    final record = await submit()(
        reviewId: 'review',
        sourceReportId: 'original',
        faults: decisions,
        identity: buildIdentity(edipi: '1087987499'));
    expect(await queue.count(), 2);
    final stored = await reports.getAllReports();
    expect(stored, hasLength(2));
    expect(
        codec.reportBody(stored.singleWhere((r) => r.entityId == 'original')),
        codec.reportBody(original));
    expect(record.maintainerReview!.signature.dodId, '1087987499');
    expect(record.signature!.dodId, original.signature!.dodId);

    final outcome = await publisher().publishPersisted(record);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(outcome.allSucceeded, isTrue);
    expect(await queue.count(), 0);
    expect(peers.broadcast.single.entityId, 'review');
    final remote = (await store.fetchRemotePmcsReports()).single;
    expect(remote.maintainerReview!.toMap(), record.maintainerReview!.toMap());
    expect(remote.faults.first.note, 'Original operator note');

    final otherDevice = FakeReportsRepository();
    await SyncRemoteReports(store, otherDevice)([]);
    expect(
        otherDevice.reports
            .singleWhere((r) => r.isMaintainerReview)
            .maintainerReview!
            .faults
            .last
            .verified,
        isFalse);
    expect(
        otherDevice.reports.singleWhere((r) => !r.isMaintainerReview).entityId,
        'original');
  });

  test(
      'offline batch survives worker restart and retries both paths without duplicate queues',
      () async {
    items.failList = true;
    peers.broadcastSucceeds = false;
    final record = await submit()(
        reviewId: 'offline-review',
        sourceReportId: 'original',
        faults: decisions,
        identity: buildIdentity());
    final outcome = await publisher().publishPersisted(record);
    expect(outcome.allFailed, isTrue);
    expect(await queue.count(), 2);
    expect((await queue.getAll()).map((row) => row.transport).toSet(),
        TransportKind.values.toSet());
    expect(
        (await queue.getAll()).every((row) => row.isMaintainerReview), isTrue);

    await worker.stop();
    items.failList = false;
    peers.broadcastSucceeds = true;
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: peers,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery);
    await worker.start();
    await worker.onProbeTick();
    expect(await queue.count(), 0);
    expect((await store.fetchRemotePmcsReports()).single.entityId,
        'offline-review');
    final peerCopy = codec.decodeReport(peers.broadcastPayloads.single,
        fromCallsign: 'peer')!;
    expect(
        peerCopy.maintainerReview!.toMap(), record.maintainerReview!.toMap());
  });

  test('a failed outbox write rolls back the batch and both queue rows',
      () async {
    await expectLater(
        submit(withQueue: FailingReviewQueue(QueuedSubmissionsDao(database)))(
            reviewId: 'failed',
            sourceReportId: 'original',
            faults: decisions,
            identity: buildIdentity()),
        throwsStateError);
    expect(
        (await reports.getAllReports()).map((r) => r.entityId), ['original']);
    expect(await queue.count(), 0);
    expect(worker.pending.values.expand((rows) => rows), isEmpty);
  });

  test('native queue worker resumes the persisted batch for both transports',
      () async {
    final record = await submit()(
        reviewId: 'native-review',
        sourceReportId: 'original',
        faults: decisions,
        identity: buildIdentity());
    final native = IsolateQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: peers,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery,
        probeInterval: const Duration(milliseconds: 10));
    addTearDown(native.stop);
    await native.start();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (await queue.count() > 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await queue.count(), 0);
    expect(
        (await store.fetchRemotePmcsReports()).single.maintainerReview!.toMap(),
        record.maintainerReview!.toMap());
    expect(
        codec
            .decodeReport(peers.broadcastPayloads.single, fromCallsign: 'peer')!
            .maintainerReview!
            .toMap(),
        record.maintainerReview!.toMap());
  });

  test(
      'partial or duplicate decisions are refused and a saved batch is idempotent',
      () async {
    for (final invalid in [
      decisions.take(1).toList(),
      [decisions.first, decisions.first]
    ]) {
      await expectLater(
          submit()(
              reviewId: 'invalid',
              sourceReportId: 'original',
              faults: invalid,
              identity: buildIdentity()),
          throwsArgumentError);
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      await submit()(
          reviewId: 'same-batch',
          sourceReportId: 'original',
          faults: decisions,
          identity: buildIdentity());
    }
    expect(await queue.count(), 2);
    expect(await reports.getAllReports(), hasLength(2));
  });

  test(
      'unsigned or corrupt incoming review data cannot become a verified batch',
      () async {
    final record = await submit()(
        reviewId: 'review',
        sourceReportId: 'original',
        faults: decisions,
        identity: buildIdentity());
    final body = codec.reportBody(record);
    final review = body['maintainerReview'] as Map<String, Object?>;
    review['signature'] = {
      'verified': false,
      'signedAt': '2026-09-30T00:00:00Z'
    };
    expect(codec.decodeReport(jsonEncode(body), fromCallsign: 'peer'), isNull);
  });
}
