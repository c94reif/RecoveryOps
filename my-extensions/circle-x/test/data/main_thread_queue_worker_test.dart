import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:circle_x/data/services/main_thread_queue_worker.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/services/queue_prompt_strategy.dart';
import 'package:circle_x/presentation/common/widgets/custom_snack_bar.dart';

import '../support/fakes.dart';

// Kept for existing callers; automatic workers must never invoke this object.
class FakeQueuePromptStrategy implements QueuePromptStrategy {
  final List<QueuedSubmission> asked = [];
  final List<bool> answers = [];
  bool defaultAnswer = true;
  @override
  Stream<QueuePromptRequest> get prompts => const Stream.empty();
  @override
  Future<bool> ask(QueuedSubmission submission) async {
    asked.add(submission);
    return answers.isEmpty ? defaultAnswer : answers.removeAt(0);
  }
}

class DeleteFailsRepository extends FakeQueuedSubmissionsRepository {
  bool failDelete = true;
  @override
  Future<void> deleteById(int id) async {
    if (failDelete) throw StateError('database unavailable');
    await super.deleteById(id);
  }
}

class GatedEntityPort extends FakePmcsEntityPort {
  final gate = Completer<bool>();
  @override
  Future<bool> publishEncodedReport(
      {required String entityId,
      required String payload,
      required LatLng position}) {
    publishedPayloads.add(payload);
    return gate.future;
  }
}

class GatedQueue extends FakeQueuedSubmissionsRepository {
  final loaded = Completer<List<QueuedSubmission>>();
  @override
  Future<List<QueuedSubmission>> getAll() => loaded.future;
}

Future<void> pumpQueue() => Future<void>.delayed(Duration.zero);

void main() {
  const interval = Duration(seconds: 5);
  late FakeQueuedSubmissionsRepository repository;
  late FakePmcsEntityPort entity;
  late FakeMeshBroadcaster mesh;
  late FakeQueuePromptStrategy prompt;
  late MainThreadQueueWorker worker;

  MainThreadQueueWorker buildWorker() => MainThreadQueueWorker(
      repository: repository,
      entityPort: entity,
      meshPort: mesh,
      promptStrategy: prompt,
      probeInterval: interval,
      snackBarService: SnackBarService.instance);

  setUp(() {
    repository = FakeQueuedSubmissionsRepository();
    entity = FakePmcsEntityPort();
    mesh = FakeMeshBroadcaster();
    prompt = FakeQueuePromptStrategy()..defaultAnswer = false;
    worker = buildWorker();
    SnackBarService.instance.queue.clear();
  });
  tearDown(() async {
    await worker.stop();
    SnackBarService.instance.queue.clear();
  });

  Future<void> enqueueBoth() async {
    for (final transport in TransportKind.values) {
      await worker.enqueue(buildQueuedSubmission(transport: transport));
    }
  }

  test('persists exact payload and row id before tracking a failed send',
      () async {
    await worker
        .enqueue(buildQueuedSubmission(payload: 'original signed data'));
    expect(repository.submissions.single.payload, 'original signed data');
    expect(
        worker.pending['lattice']!.single.id, repository.submissions.single.id);
    expect(await worker.pendingCount(), 1);
    expect(worker.connected['lattice'], isFalse);
    expect(worker.connected['mesh'], isTrue);
    expect(SnackBarService.instance.queue.single.message, contains('queued'));
  });

  test('successful transport outcome automatically drains FIFO without prompts',
      () async {
    for (final id in ['a', 'b', 'c']) {
      await worker.enqueue(buildQueuedSubmission(entityId: id, payload: id));
    }
    SnackBarService.instance.queue.clear();
    worker.reportTransportOutcome(
        transport: TransportKind.lattice, success: true);
    await pumpQueue();
    expect(entity.publishedPayloads, ['a', 'b', 'c']);
    expect(prompt.asked, isEmpty);
    expect(repository.submissions, isEmpty);
    expect(SnackBarService.instance.queue, isEmpty);
  });

  test('failed outcome retains durable queue without sending or prompting',
      () async {
    await enqueueBoth();
    worker.reportTransportOutcome(
        transport: TransportKind.lattice, success: false);
    await pumpQueue();
    expect(repository.submissions, hasLength(2));
    expect(entity.publishedPayloads, isEmpty);
    expect(prompt.asked, isEmpty);
  });

  test('mesh success only drains mesh', () async {
    await enqueueBoth();
    worker.reportTransportOutcome(transport: TransportKind.mesh, success: true);
    await pumpQueue();
    expect(mesh.broadcastPayloads, hasLength(1));
    expect(entity.publishedPayloads, isEmpty);
    expect(repository.submissions.single.transport, TransportKind.lattice);
  });

  test('startup immediately drains durable rows without blocking on sends',
      () async {
    final gated = GatedEntityPort();
    entity = gated;
    worker = buildWorker();
    await repository.insert(buildQueuedSubmission());
    await worker.start().timeout(const Duration(seconds: 1));
    await pumpQueue();
    expect(entity.publishedPayloads, hasLength(1));
    expect(repository.submissions, hasLength(1));
    gated.gate.complete(true);
    await worker.onProbeTick();
    expect(repository.submissions, isEmpty);
    expect(prompt.asked, isEmpty);
  });

  test('one blocked transport cannot block the other transport', () async {
    final gated = GatedEntityPort();
    entity = gated;
    worker = buildWorker();
    await enqueueBoth();
    await worker.start();
    await pumpQueue();
    expect(mesh.broadcastPayloads, hasLength(1));
    expect(repository.submissions.single.transport, TransportKind.lattice);
    gated.gate.complete(true);
    await worker.onProbeTick();
    expect(repository.submissions, isEmpty);
  });

  test('send now delivers a mesh row while lattice is blocked', () async {
    final gated = GatedEntityPort();
    entity = gated;
    worker = buildWorker();
    mesh.broadcastSucceeds = false;
    await enqueueBoth();
    await worker.start();
    await pumpQueue();
    expect(mesh.broadcastPayloads, hasLength(1));

    mesh.broadcastSucceeds = true;
    final meshRow = repository.submissions
        .singleWhere((row) => row.transport == TransportKind.mesh);
    expect(await worker.sendNow(meshRow), isTrue);

    expect(mesh.broadcastPayloads, hasLength(2));
    expect(repository.submissions.single.transport, TransportKind.lattice);
    gated.gate.complete(true);
  });

  test('send now reports a failed attempt and keeps the row', () async {
    mesh.broadcastSucceeds = false;
    await worker.enqueue(buildQueuedSubmission(transport: TransportKind.mesh));
    expect(await worker.sendNow(repository.submissions.single), isFalse);
    await worker.start();
    await pumpQueue();

    expect(await worker.sendNow(repository.submissions.single), isFalse);

    expect(mesh.broadcastPayloads, hasLength(2));
    expect(repository.submissions, hasLength(1));
  });

  test('concurrent probes join one send and duplicate tracking is harmless',
      () async {
    final gated = GatedEntityPort();
    entity = gated;
    worker = buildWorker();
    await worker.enqueue(buildQueuedSubmission());
    worker.trackPersisted(repository.submissions.single);
    final first = worker.nudge(TransportKind.lattice);
    final second = worker.nudge(TransportKind.lattice);
    await pumpQueue();
    expect(entity.publishedPayloads, hasLength(1));
    gated.gate.complete(true);
    await Future.wait([first, second]);
    expect(repository.submissions, isEmpty);
  });

  test('failure stops only its transport and retains all its rows', () async {
    await enqueueBoth();
    await worker.enqueue(buildQueuedSubmission(entityId: 'another'));
    entity.publishSucceeds = false;
    await worker.onProbeTick();
    expect(entity.publishedPayloads, hasLength(1));
    expect(mesh.broadcastPayloads, hasLength(1));
    expect(repository.submissions, hasLength(2));
    expect(
        repository.submissions
            .every((row) => row.transport == TransportKind.lattice),
        isTrue);
  });

  test(
      'periodic offline retries use bounded exponential backoff and remain quiet',
      () {
    fakeAsync((async) {
      entity.publishSucceeds = false;
      unawaited(worker.enqueue(buildQueuedSubmission()));
      async.flushMicrotasks();
      SnackBarService.instance.queue.clear();
      unawaited(worker.start());
      async.flushMicrotasks();
      expect(entity.publishedPayloads, hasLength(1));
      for (final attempts in [2, 2, 3, 3, 3, 3, 4]) {
        async.elapse(interval);
        expect(entity.publishedPayloads, hasLength(attempts));
      }
      entity.publishSucceeds = true;
      unawaited(worker.retryNow());
      async.flushMicrotasks();
      expect(repository.submissions, isEmpty);
      expect(SnackBarService.instance.queue, isEmpty);
      unawaited(worker.stop());
      async.flushMicrotasks();
    });
  });

  test('connectivity success bypasses retry backoff immediately', () async {
    await worker.enqueue(buildQueuedSubmission());
    entity.publishSucceeds = false;
    await worker.onProbeTick();
    await worker.onProbeTick();
    entity.publishSucceeds = true;
    worker.reportTransportOutcome(
        transport: TransportKind.lattice, success: true);
    await pumpQueue();
    expect(entity.publishedPayloads, hasLength(3));
    expect(repository.submissions, isEmpty);
  });

  test('failed local deletion remains tracked and retries without another send',
      () async {
    final failing = DeleteFailsRepository();
    repository = failing;
    worker = buildWorker();
    await worker.enqueue(buildQueuedSubmission());
    await worker.onProbeTick();
    expect(repository.submissions, hasLength(1));
    expect(worker.pending['lattice'], hasLength(1));
    failing.failDelete = false;
    await worker.retryNow();
    expect(repository.submissions, isEmpty);
    expect(entity.publishedPayloads, hasLength(1));
  });

  test('restart resumes durable rows and second start does not duplicate sends',
      () async {
    await worker.enqueue(buildQueuedSubmission());
    await worker.stop();
    expect(repository.submissions, hasLength(1));
    await worker.start();
    await worker.start();
    await worker.onProbeTick();
    expect(entity.publishedPayloads, hasLength(1));
    expect(repository.submissions, isEmpty);
  });

  test('stop during startup prevents late timer installation', () async {
    final gated = GatedQueue();
    repository = gated;
    worker = buildWorker();
    final starting = worker.start();
    await worker.stop();
    gated.loaded.complete([buildQueuedSubmission(id: 1)]);
    await starting;
    expect(worker.probeTimer, isNull);
    expect(entity.publishedPayloads, isEmpty);
  });

  test(
      'stop during send leaves durable row for restart and ignores stale drain',
      () async {
    final gated = GatedEntityPort();
    entity = gated;
    worker = buildWorker();
    await worker.enqueue(buildQueuedSubmission());
    final sending = worker.onProbeTick();
    await pumpQueue();
    await worker.stop();
    gated.gate.complete(true);
    await sending;
    expect(repository.submissions, hasLength(1));
    expect(worker.pending.values.expand((rows) => rows), isEmpty);
  });

  test('withdrawn review source suppresses queued review payload', () async {
    await worker.enqueue(buildQueuedSubmission(
        payload: '{"maintainerReview":{"sourceReportId":"original"}}'));
    worker.delivery.suppressReport('original');
    await worker.onProbeTick();
    expect(repository.submissions, isEmpty);
    expect(entity.publishedPayloads, isEmpty);
  });

  test('stop cancels automatic probes', () {
    fakeAsync((async) {
      unawaited(worker.start());
      async.flushMicrotasks();
      unawaited(worker.stop());
      async.flushMicrotasks();
      unawaited(worker.enqueue(buildQueuedSubmission()));
      async.flushMicrotasks();
      async.elapse(interval * 20);
      expect(entity.publishedPayloads, isEmpty);
      expect(repository.submissions, hasLength(1));
    });
  });
}
