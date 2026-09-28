import 'package:ivy_pulse/domain/services/clock.dart';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/data/repositories/queued_submissions_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/reports_repo_impl.dart';
import 'package:ivy_pulse/data/services/drift_transaction_runner.dart';
import 'package:ivy_pulse/data/services/isolate_queue_worker.dart';
import 'package:ivy_pulse/data/services/lattice_pmcs_adapter.dart';
import 'package:ivy_pulse/data/services/lattice_report_source.dart';
import 'package:ivy_pulse/data/services/main_thread_queue_worker.dart';
import 'package:ivy_pulse/data/services/sdk_mesh_broadcaster.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';

import '../support/fakes.dart';
import 'lattice_pmcs_adapter_test.dart' as entity_fake;
import 'lattice_report_source_test.dart' as source_fake;
import 'main_thread_queue_worker_test.dart' show FakeQueuePromptStrategy;
import 'sdk_mesh_broadcaster_test.dart' as mesh_fake;

class FailingWithdrawalQueue extends QueuedSubmissionsRepoImpl {
  FailingWithdrawalQueue(super.dao);
  int inserts = 0;
  @override
  Future<QueuedSubmission> insert(QueuedSubmission submission) {
    if (++inserts == 2) throw StateError('disk full');
    return super.insert(submission);
  }
}

class BlockedPrompt extends FakeQueuePromptStrategy {
  final answer = Completer<bool>();
  @override
  Future<bool> ask(QueuedSubmission submission) {
    if (submission.transport == TransportKind.lattice) return answer.future;
    return super.ask(submission);
  }
}

class StartupQueue extends FakeQueuedSubmissionsRepository {
  final loaded = Completer<List<QueuedSubmission>>();
  @override
  Future<List<QueuedSubmission>> getAll() => loaded.future;
}

void main() {
  late AppDatabase db;
  late ReportsRepoImpl reports;
  late QueuedSubmissionsRepoImpl queue;
  late DeliveryCoordinator delivery;
  late entity_fake.FakeEntityService entities;
  late mesh_fake.FakeMessagingService messaging;
  late LatticePmcsAdapter entityPort;
  late SdkMeshBroadcaster meshPort;
  late MainThreadQueueWorker worker;
  const codec = PmcsReportCodec();

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    reports = ReportsRepoImpl(PmcsReportsDao(db));
    queue = QueuedSubmissionsRepoImpl(QueuedSubmissionsDao(db));
    delivery = DeliveryCoordinator(reportsRepository: reports);
    entities = entity_fake.FakeEntityService();
    messaging = mesh_fake.FakeMessagingService();
    entityPort = LatticePmcsAdapter(entities: entities);
    meshPort = SdkMeshBroadcaster(messaging: messaging);
    worker = MainThreadQueueWorker(
        repository: queue,
        entityPort: entityPort,
        meshPort: meshPort,
        promptStrategy: FakeQueuePromptStrategy(),
        delivery: delivery);
  });
  tearDown(() async {
    await worker.stop();
    // Let a completed direct send's queue settlement finish before closing SQLite.
    await Future<void>.delayed(Duration.zero);
    await db.close();
    await delivery.dispose();
  });

  PublishPmcsDeletion deletion({QueuedSubmissionsRepoImpl? queueOverride}) =>
      PublishPmcsDeletion(
          codec: const PmcsReportCodec(),
          entityPort: entityPort,
          meshPort: meshPort,
          queueWorker: worker,
          repository: reports,
          delivery: delivery,
          queuedRepository: queueOverride ?? queue,
          transaction: DriftTransactionRunner(db));

  test('entity and mesh carry the same signed report, including queued retries',
      () async {
    final report = buildReport(
        signature: buildSignature(),
        faults: [buildFault(note: 'Visible leak')]);
    entities.throwsOnUpsert = true;
    messaging.results = [];
    final publish = PublishPmcsReport(
        entityPort: entityPort,
        meshPort: meshPort,
        queueWorker: worker,
        codec: codec,
        clock: FixedClock(DateTime.utc(2026)),
        delivery: delivery);
    expect((await publish(report)).allFailed, isTrue);
    final parked = await queue.getAll();
    expect(parked, hasLength(2));
    expect(parked.map((s) => s.payload).toSet(), {codec.encodeReport(report)});
    entities.throwsOnUpsert = false;
    messaging.results = [
      const sdk.DeliveryResult(peerId: 'receiver', success: true)
    ];
    await worker.onProbeTick();
    expect(await queue.count(), 0);
    expect(entities.stored[report.entityId]!.description,
        messaging.broadcasts.last);
    final received =
        codec.decodeReport(messaging.broadcasts.last, fromCallsign: 'ALPHA')!;
    expect(received.faults.single.note, 'Visible leak');
    expect(received.signature!.toMap(), report.signature!.toMap());
  });

  for (final native in [false, true]) {
    test(
        '${native ? 'native' : 'web'} restart retries offline withdrawals without republishing reports',
        () async {
      final report = await reports.insertReport(buildReport());
      await entityPort.publishPmcsReport(report);
      entities.throwsOnUpsert = true;
      messaging.results = [];
      // A report retry left over from an earlier failed acknowledgement.
      for (final transport in TransportKind.values) {
        await worker.enqueue(buildQueuedSubmission(
            payload: codec.encodeReport(report), transport: transport));
      }
      expect((await deletion()(report)).allFailed, isTrue);
      expect(await reports.getAllReports(), isEmpty);
      expect(await reports.getWithdrawnIds(), {report.entityId});
      expect(await queue.count(), 4);
      await worker.stop();
      await delivery.dispose();
      delivery = DeliveryCoordinator(reportsRepository: reports);
      entities.throwsOnUpsert = false;
      messaging.results = [
        const sdk.DeliveryResult(peerId: 'receiver', success: true)
      ];
      entities.upserted.clear();
      messaging.broadcasts.clear();
      final QueueWorkerStrategy resumed;
      if (native) {
        resumed = IsolateQueueWorker(
            repository: queue,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: FakeQueuePromptStrategy(),
            delivery: delivery,
            probeInterval: const Duration(milliseconds: 10));
      } else {
        resumed = MainThreadQueueWorker(
            repository: queue,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: FakeQueuePromptStrategy(),
            delivery: delivery);
      }
      await resumed.start();
      try {
        if (resumed is MainThreadQueueWorker) {
          await resumed.onProbeTick();
        } else {
          await (() async {
            while (await queue.count() != 0) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          })()
              .timeout(const Duration(seconds: 5));
        }
        expect(await queue.count(), 0);
        expect(entities.upserted, hasLength(1));
        expect(entities.upserted.single.isLive, isFalse);
        expect(messaging.broadcasts, hasLength(1));
        expect(
            codec.decodeDeletion(messaging.broadcasts.single), report.entityId);
        await expectLater(
            reports.insertReport(report), throwsA(isA<ReportWithdrawn>()));
      } finally {
        await resumed.stop();
      }
    });
  }

  test(
      'failure to save the second withdrawal rolls back deletion and both queue rows',
      () async {
    final report = await reports.insertReport(buildReport());
    await expectLater(
        deletion(
            queueOverride:
                FailingWithdrawalQueue(QueuedSubmissionsDao(db)))(report),
        throwsStateError);
    expect(await queue.count(), 0);
    expect(await reports.getWithdrawnIds(), isEmpty);
    expect(await reports.getAllReports(), hasLength(1));
    expect(entities.upserted, isEmpty);
    expect(messaging.broadcasts, isEmpty);
    expect(worker.pending.values.expand((rows) => rows), isEmpty);
  });

  test(
      'withdrawal waits for an in-flight publication before sending its tombstone',
      () async {
    final gate = Completer<bool>();
    final began = Completer<void>();
    final order = <String>[];
    final publication =
        delivery.send('report', TransportKind.lattice, () async {
      began.complete();
      await gate.future;
      order.add('report');
      return true;
    });
    await began.future;
    final withdrawal = delivery.send('report', TransportKind.lattice, () async {
      order.add('withdrawal');
      return true;
    }, withdrawal: true);
    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty);
    gate.complete(true);
    await Future.wait([publication, withdrawal]);
    expect(order, ['report', 'withdrawal']);
    await delivery.send('report', TransportKind.mesh, () async {
      fail('A withdrawn report must not be rebroadcast');
    });
  });

  test('host tombstones remove a saved report and block a stale host snapshot',
      () async {
    final report = await reports.insertReport(buildReport(isOutgoing: false));
    final source = FakeRemoteReportSource()
      ..withdrawnIds = {report.entityId}
      ..remote = [report];
    expect(await SyncRemoteReports(source, reports)([report]), isEmpty);
    expect(await reports.getAllReports(), isEmpty);
    expect(await reports.getWithdrawnIds(), {report.entityId});
  });

  test('a blocked Lattice prompt does not block mesh retries on the web',
      () async {
    final prompt = BlockedPrompt();
    final independent = MainThreadQueueWorker(
        repository: queue,
        entityPort: entityPort,
        meshPort: meshPort,
        promptStrategy: prompt,
        delivery: delivery);
    for (final transport in TransportKind.values) {
      await queue.insert(buildQueuedSubmission(
          payload: codec.encodeReport(buildReport()), transport: transport));
    }
    await independent.start();
    final probing = independent.onProbeTick();
    await (() async {
      while (messaging.broadcasts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
    })()
        .timeout(const Duration(seconds: 3));
    expect(entities.upserted, isEmpty);
    prompt.answer.complete(true);
    await probing;
    expect(await queue.count(), 0);
    await independent.stop();
  });
  test('a failed host listing cannot trigger repair publication', () async {
    final host = source_fake.FakeEntityService()..throwsOnGetEntities = true;
    final source = LatticeReportSource(entities: host);
    final repair =
        SyncLocalReportsToLattice(source, entityPort, delivery: delivery);
    expect(await repair([buildReport()]), 0);
    expect(entities.upserted, isEmpty);
  });

  for (final native in [false, true]) {
    test(
        '${native ? 'native' : 'web'} startup keeps rows queued while its database snapshot loads',
        () async {
      final pending = StartupQueue();
      final QueueWorkerStrategy starting = native
          ? IsolateQueueWorker(
              repository: pending,
              entityPort: entityPort,
              meshPort: meshPort,
              delivery: delivery,
              promptStrategy: FakeQueuePromptStrategy(),
              probeInterval: const Duration(milliseconds: 10))
          : MainThreadQueueWorker(
              repository: pending,
              entityPort: entityPort,
              meshPort: meshPort,
              delivery: delivery,
              promptStrategy: FakeQueuePromptStrategy());
      final firstStart = starting.start();
      final secondStart = starting.start();
      expect(identical(firstStart, secondStart), isTrue);
      await starting.enqueue(
          buildQueuedSubmission(payload: codec.encodeReport(buildReport())));
      pending.loaded.complete([]);
      await firstStart;
      try {
        if (starting is MainThreadQueueWorker) {
          await starting.onProbeTick();
        } else {
          await (() async {
            while (pending.submissions.isNotEmpty) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          })()
              .timeout(const Duration(seconds: 5));
        }
        expect(pending.submissions, isEmpty);
        expect(entities.upserted, hasLength(1));
      } finally {
        await starting.stop();
      }
    });
  }
}
