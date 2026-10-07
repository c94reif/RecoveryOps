import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/usecases/reporting/sync_local_reports_to_lattice.dart';

import '../../../support/fakes.dart';

class ThrowingRelayPort extends FakePmcsEntityPort {
  @override
  Future<bool> publishPmcsReport(PmcsReport report) {
    if (report.entityId == 'broken') throw StateError('unavailable');
    return super.publishPmcsReport(report);
  }
}

class FailingRelayQueue extends FakeQueueWorker {
  @override
  Future<void> enqueue(QueuedSubmission submission) async {
    throw StateError('disk temporarily unavailable');
  }
}

void main() {
  const codec = PmcsReportCodec();
  late FakeRemoteReportSource source;
  late FakeReportsRepository reports;
  late FakePmcsEntityPort entity;
  late FakeQueuedSubmissionsRepository queue;
  late FakeQueueWorker worker;
  late DeliveryCoordinator delivery;
  final now = DateTime.utc(2026, 10, 6);
  final review = buildReport(
    entityId: 'review',
    isOutgoing: false,
    faults: [buildFault(itemId: 'engine')],
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
    source = FakeRemoteReportSource();
    reports = FakeReportsRepository();
    entity = ThrowingRelayPort();
    queue = FakeQueuedSubmissionsRepository();
    worker = FakeQueueWorker();
    delivery = DeliveryCoordinator(reportsRepository: reports);
  });
  tearDown(() => delivery.dispose());

  SyncLocalReportsToLattice relay() => SyncLocalReportsToLattice(
        source,
        entity,
        delivery: delivery,
        reportsRepository: reports,
        queuedRepository: queue,
        queueWorker: worker,
        codec: codec,
        clock: FixedClock(now),
      );

  test('relays an incoming maintainer review and deduplicates repeated IDs',
      () async {
    expect(await relay()([review, review]), 1);
    expect(entity.published, [review]);
    expect(entity.published.single.maintainerReview, review.maintainerReview);
    expect(worker.enqueued, isEmpty);
  });

  test('failed peer relay queues its exact payload only for the shared store',
      () async {
    entity.publishSucceeds = false;
    expect(await relay()([review]), 0);
    final row = worker.enqueued.single;
    expect(row.payload, codec.encodeReport(review));
    expect(row.transport, TransportKind.lattice);
    expect(row.createdAt, now);
    expect(row.isMaintainerReview, isTrue);
    expect(delivery.status('review', TransportKind.lattice),
        DeliveryStatus.queued);
    expect(await relay()([review]), 0);
    expect(worker.enqueued, hasLength(1));
  });

  test('one throwing transport does not prevent the other reports relaying',
      () async {
    expect(await relay()([buildReport(entityId: 'broken'), review]), 1);
    expect(entity.published, [review]);
    expect(worker.enqueued.single.entityId, 'broken');
  });

  test('a queue persistence failure leaves the stored report retryable',
      () async {
    worker = FailingRelayQueue();
    entity.publishSucceeds = false;
    expect(await relay()([review]), 0);
    expect(delivery.status('review', TransportKind.lattice),
        DeliveryStatus.failed);
    entity.publishSucceeds = true;
    expect(await relay()([review]), 1);
    expect(entity.published, hasLength(2));
  });

  test('restored durable retry rows prevent duplicate relay after a restart',
      () async {
    await queue.insert(buildQueuedSubmission(
        entityId: review.entityId, payload: codec.encodeReport(review)));
    expect(await relay()([review]), 0);
    expect(entity.published, isEmpty);
    expect(worker.enqueued, isEmpty);
  });

  test('a peer withdrawal reaches the store without a remaining report row',
      () async {
    await reports.withdrawReport('original');
    expect(await relay()([]), 1);
    expect(entity.deletedIds, ['original']);
    expect(entity.published, isEmpty);
  });

  test('failed withdrawal relays persist a deletion retry and suppress reports',
      () async {
    await reports.withdrawReport('original');
    entity.deleteSucceeds = false;
    expect(await relay()([buildReport(entityId: 'original'), review]), 0);
    expect(entity.published, isEmpty);
    final row = worker.enqueued.single;
    expect(row.entityId, 'original');
    expect(row.isWithdrawal, isTrue);
    expect(row.transport, TransportKind.lattice);
    expect(delivery.status('original', TransportKind.lattice, withdrawal: true),
        DeliveryStatus.queued);
    expect(await relay()([review]), 0);
    expect(entity.deletedIds, ['original']);
  });

  test('a queued withdrawal is left for the automatic queue worker', () async {
    await reports.withdrawReport('original');
    await queue.insert(buildQueuedSubmission(
        entityId: 'original', payload: codec.encodeDeletion('original')));
    expect(await relay()([review]), 0);
    expect(entity.deletedIds, isEmpty);
    expect(entity.published, isEmpty);
  });

  test(
      'remote source tombstones suppress a review even with a stale ID listing',
      () async {
    source.withdrawnIds = {'original'};
    expect(await relay()([buildReport(entityId: 'original'), review]), 0);
    expect(entity.published, isEmpty);
    expect(entity.deletedIds, isEmpty);
    expect(await reports.getWithdrawnIds(), {'original'});
  });

  test('local review tombstones never upload the withdrawn review', () async {
    await reports.withdrawReport('review');
    expect(await relay()([review]), 1);
    expect(entity.deletedIds, ['review']);
    expect(entity.published, isEmpty);
  });

  test('existing remote withdrawals need no further writes', () async {
    await reports.withdrawReport('original');
    source.withdrawnIds = {'original'};
    expect(await relay()([]), 0);
    expect(entity.deletedIds, isEmpty);
  });
}
