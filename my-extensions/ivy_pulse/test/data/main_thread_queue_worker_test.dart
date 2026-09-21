import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/main_thread_queue_worker.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';

import '../support/fakes.dart';

/// Answers the queue's prompt from a script, so a test can say "send this one,
/// discard the next" without standing up a widget tree.
class FakeQueuePromptStrategy implements QueuePromptStrategy {
  final List<QueuedSubmission> asked = [];
  final List<bool> answers = [];
  bool defaultAnswer = true;

  @override
  Stream<QueuePromptRequest> get prompts => const Stream.empty();

  @override
  Future<bool> ask(QueuedSubmission submission) async {
    asked.add(submission);
    if (answers.isEmpty) return defaultAnswer;
    return answers.removeAt(0);
  }
}

/// A database that takes the delete call and then loses it — the drain has to
/// carry on regardless.
class DeleteFailsRepository extends FakeQueuedSubmissionsRepository {
  @override
  Future<void> deleteById(int id) async {
    deletedIds.add(id);
    throw StateError('database gone');
  }
}

/// Lets every microtask the worker chained off an unawaited drain run out.
Future<void> pumpQueue() => Future<void>.delayed(Duration.zero);

void main() {
  const probeInterval = Duration(seconds: 5);

  late FakeQueuedSubmissionsRepository repository;
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late FakeQueuePromptStrategy promptStrategy;
  late MainThreadQueueWorker worker;

  MainThreadQueueWorker buildWorker({
    FakeQueuedSubmissionsRepository? withRepository,
  }) =>
      MainThreadQueueWorker(
        repository: withRepository ?? repository,
        entityPort: entityPort,
        meshPort: meshPort,
        promptStrategy: promptStrategy,
        probeInterval: probeInterval,
      );

  List<String> messages() =>
      SnackBarService.instance.queue.map((m) => m.message).toList();

  setUp(() {
    repository = FakeQueuedSubmissionsRepository();
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    promptStrategy = FakeQueuePromptStrategy();
    worker = buildWorker();
    SnackBarService.instance.queue.clear();
  });

  tearDown(() async {
    await worker.stop();
    SnackBarService.instance.queue.clear();
  });

  group('enqueue', () {
    test('parks the submission on disk so a killed app can resume it',
        () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:a'));

      expect(repository.submissions, hasLength(1));
      expect(repository.submissions.single.payload, 'encoded:a');
      expect(repository.submissions.single.id, isNotNull);
    });

    test('holds the stored row, with its id, in the transport backlog',
        () async {
      await worker.enqueue(buildQueuedSubmission());

      expect(worker.pending['lattice']!.single.id, 1);
    });

    test('marks that transport down', () async {
      await worker.enqueue(buildQueuedSubmission());

      expect(worker.connected['lattice'], isFalse);
    });

    test('tells the operator the submission was queued, not lost', () async {
      await worker.enqueue(buildQueuedSubmission());

      final notice = SnackBarService.instance.queue.single;
      expect(notice.message,
          'Lattice unreachable — queued, will send on reconnect');
      expect(notice.isError, isTrue);
    });

    test('parking a Lattice submission does not take the mesh leg down',
        () async {
      await worker.enqueue(buildQueuedSubmission());

      expect(worker.connected['mesh'], isTrue);
      expect(worker.pending['mesh'], isEmpty);
    });

    test('keeps each transport backlog separate', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:lattice'));
      await worker.enqueue(
        buildQueuedSubmission(
          payload: 'encoded:mesh',
          transport: TransportKind.mesh,
        ),
      );

      expect(worker.pending['lattice']!.single.payload, 'encoded:lattice');
      expect(worker.pending['mesh']!.single.payload, 'encoded:mesh');
    });
  });

  group('reportTransportOutcome', () {
    test('a live send that lands starts draining that backlog', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:parked'));

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(entityPort.publishedPayloads, ['encoded:parked']);
      expect(repository.submissions, isEmpty);
    });

    test('a live send that fails leaves the leg down and the backlog parked',
        () async {
      await worker.enqueue(buildQueuedSubmission());

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: false,
      );
      await pumpQueue();

      expect(worker.connected['lattice'], isFalse);
      expect(promptStrategy.asked, isEmpty);
      expect(repository.submissions, hasLength(1));
    });

    test('a mesh success drains mesh and leaves the Lattice backlog parked',
        () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:lattice'));
      await worker.enqueue(
        buildQueuedSubmission(
          payload: 'encoded:mesh',
          transport: TransportKind.mesh,
        ),
      );

      worker.reportTransportOutcome(
        transport: TransportKind.mesh,
        success: true,
      );
      await pumpQueue();

      expect(meshPort.broadcastPayloads, ['encoded:mesh']);
      expect(entityPort.publishedPayloads, isEmpty);
      expect(
        repository.submissions.single.transport,
        TransportKind.lattice,
      );
      expect(worker.connected['lattice'], isFalse);
    });

    test('a success with nothing parked is harmless', () async {
      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(worker.connected['lattice'], isTrue);
      expect(promptStrategy.asked, isEmpty);
      expect(entityPort.publishedPayloads, isEmpty);
    });
  });

  group('draining a leg that came back', () {
    test('asks the operator before re-sending anything', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:parked'));
      promptStrategy.defaultAnswer = false;

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(promptStrategy.asked.single.payload, 'encoded:parked');
    });

    test('a send answer publishes the submission and drops the row', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:parked'));
      promptStrategy.answers.add(true);

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(entityPort.publishedPayloads, ['encoded:parked']);
      expect(repository.deletedIds, [1]);
      expect(worker.pending['lattice'], isEmpty);
    });

    test('a discard answer drops the row without publishing it', () async {
      await worker.enqueue(buildQueuedSubmission());
      promptStrategy.answers.add(false);

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(entityPort.publishedPayloads, isEmpty);
      expect(repository.deletedIds, [1]);
      expect(repository.submissions, isEmpty);
    });

    test('re-sends the stored payload verbatim rather than rebuilding it',
        () async {
      await worker.enqueue(
        buildQueuedSubmission(payload: 'encoded:from-an-hour-ago'),
      );

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(entityPort.publishedPayloads, ['encoded:from-an-hour-ago']);
      expect(entityPort.published, isEmpty);
    });

    test('keeps draining while the leg holds up', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:a'));
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:b'));
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:c'));

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(promptStrategy.asked, hasLength(3));
      expect(
        entityPort.publishedPayloads,
        ['encoded:a', 'encoded:b', 'encoded:c'],
      );
      expect(repository.submissions, isEmpty);
    });

    test('offers the oldest parked submission first', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:oldest'));
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:newer'));
      promptStrategy.answers.addAll([false, false]);

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(
        promptStrategy.asked.map((s) => s.payload),
        ['encoded:oldest', 'encoded:newer'],
      );
    });

    test('a send that fails mid-drain stops that leg and parks the rest',
        () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:a'));
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:b'));
      entityPort.publishSucceeds = false;

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(promptStrategy.asked, hasLength(1));
      expect(entityPort.publishedPayloads, ['encoded:a']);
      expect(repository.submissions, hasLength(2));
      expect(repository.deletedIds, isEmpty);
      expect(worker.connected['lattice'], isFalse);
    });

    test('a failed drain leaves the leg ready to be offered again', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:a'));
      entityPort.publishSucceeds = false;
      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      entityPort.publishSucceeds = true;
      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(promptStrategy.asked, hasLength(2));
      expect(entityPort.publishedPayloads, ['encoded:a', 'encoded:a']);
      expect(repository.submissions, isEmpty);
    });

    test('tells the operator when a queued submission finally lands', () async {
      await worker.enqueue(buildQueuedSubmission());
      SnackBarService.instance.queue.clear();

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(messages(), ['Lattice: sent (queued)']);
      expect(SnackBarService.instance.queue.single.isError, isFalse);
    });

    test('tells the operator when the re-send fails', () async {
      await worker.enqueue(buildQueuedSubmission());
      entityPort.publishSucceeds = false;
      SnackBarService.instance.queue.clear();

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(messages(), ['Lattice: still FAILED']);
      expect(SnackBarService.instance.queue.single.isError, isTrue);
    });

    test('does not offer a discarded submission a second time', () async {
      await worker.enqueue(buildQueuedSubmission());
      promptStrategy.defaultAnswer = false;
      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(promptStrategy.asked, hasLength(1));
    });

    test('keeps draining when the row delete fails', () async {
      final failing = DeleteFailsRepository();
      final other = buildWorker(withRepository: failing);
      await other.enqueue(buildQueuedSubmission(payload: 'encoded:a'));
      await other.enqueue(buildQueuedSubmission(payload: 'encoded:b'));

      other.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(entityPort.publishedPayloads, ['encoded:a', 'encoded:b']);
      expect(other.pending['lattice'], isEmpty);
      // TODO: a delete that throws leaves the row on disk, so the next start()
      // resumes a PMCS that has already been delivered.
      expect(failing.submissions, hasLength(2));
    });
  });

  group('probing a down leg', () {
    test('re-sends the oldest parked submission when the interval elapses', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission(payload: 'encoded:a')));
        async.flushMicrotasks();

        async.elapse(probeInterval);
        async.flushMicrotasks();

        expect(entityPort.publishedPayloads, ['encoded:a']);
        expect(repository.submissions, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('does not ask the operator about the submission it probes with', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission()));
        async.flushMicrotasks();

        async.elapse(probeInterval);
        async.flushMicrotasks();

        expect(promptStrategy.asked, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('leaves everything parked, and stays quiet, when the probe fails', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission()));
        async.flushMicrotasks();
        entityPort.publishSucceeds = false;
        SnackBarService.instance.queue.clear();

        async.elapse(probeInterval * 3);
        async.flushMicrotasks();

        expect(repository.submissions, hasLength(1));
        expect(worker.connected['lattice'], isFalse);
        expect(messages(), isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('retries a down leg on every tick until it gets through', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission(payload: 'encoded:a')));
        async.flushMicrotasks();
        entityPort.publishSucceeds = false;

        async.elapse(probeInterval * 2);
        async.flushMicrotasks();
        expect(entityPort.publishedPayloads, hasLength(2));

        entityPort.publishSucceeds = true;
        async.elapse(probeInterval);
        async.flushMicrotasks();

        expect(repository.submissions, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('offers the rest of the backlog once a probe gets through', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission(payload: 'encoded:a')));
        async.flushMicrotasks();
        unawaited(worker.enqueue(buildQueuedSubmission(payload: 'encoded:b')));
        async.flushMicrotasks();

        async.elapse(probeInterval);
        async.flushMicrotasks();

        expect(promptStrategy.asked.map((s) => s.payload), ['encoded:b']);
        expect(entityPort.publishedPayloads, ['encoded:a', 'encoded:b']);
        expect(repository.submissions, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('never probes a leg with nothing parked', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();

        async.elapse(probeInterval * 5);
        async.flushMicrotasks();

        expect(entityPort.publishedPayloads, isEmpty);
        expect(meshPort.broadcastPayloads, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });
  });

  group('start and stop', () {
    test('resumes rows left on disk by a previous run', () async {
      repository.submissions.addAll([
        buildQueuedSubmission(id: 1, payload: 'encoded:a'),
        buildQueuedSubmission(
          id: 2,
          payload: 'encoded:b',
          transport: TransportKind.mesh,
        ),
      ]);

      await worker.start();

      expect(worker.pending['lattice']!.single.payload, 'encoded:a');
      expect(worker.pending['mesh']!.single.payload, 'encoded:b');
    });

    test('offers a resumed row on the first tick, assuming the leg is up', () {
      repository.submissions.add(
        buildQueuedSubmission(id: 1, payload: 'encoded:a'),
      );

      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();

        async.elapse(probeInterval);
        async.flushMicrotasks();

        expect(promptStrategy.asked.single.payload, 'encoded:a');
        expect(entityPort.publishedPayloads, ['encoded:a']);
        expect(repository.submissions, isEmpty);

        unawaited(worker.stop());
        async.flushMicrotasks();
      });
    });

    test('a second start does not resume the same rows twice', () async {
      repository.submissions.add(buildQueuedSubmission(id: 1));

      await worker.start();
      await worker.start();

      expect(worker.pending['lattice'], hasLength(1));
    });

    test('stop cancels the probe timer', () {
      fakeAsync((async) {
        unawaited(worker.start());
        async.flushMicrotasks();
        unawaited(worker.stop());
        async.flushMicrotasks();

        unawaited(worker.enqueue(buildQueuedSubmission()));
        async.flushMicrotasks();
        async.elapse(probeInterval * 5);
        async.flushMicrotasks();

        expect(worker.probeTimer, isNull);
        expect(entityPort.publishedPayloads, isEmpty);
      });
    });

    test('stop leaves the rows on disk so a restart can resume them', () async {
      await worker.enqueue(buildQueuedSubmission(payload: 'encoded:a'));

      await worker.stop();

      expect(worker.pending['lattice'], isEmpty);
      expect(repository.submissions, hasLength(1));

      await worker.start();

      expect(worker.pending['lattice']!.single.payload, 'encoded:a');
    });
  });

  group('pendingCount', () {
    test('reports what is on disk, not what the worker has in memory',
        () async {
      repository.submissions.addAll([
        buildQueuedSubmission(id: 1),
        buildQueuedSubmission(id: 2, transport: TransportKind.mesh),
      ]);

      expect(await worker.pendingCount(), 2);
      expect(worker.pending['lattice'], isEmpty);
    });

    test('drops back to zero once the backlog drains', () async {
      await worker.enqueue(buildQueuedSubmission());
      expect(await worker.pendingCount(), 1);

      worker.reportTransportOutcome(
        transport: TransportKind.lattice,
        success: true,
      );
      await pumpQueue();

      expect(await worker.pendingCount(), 0);
    });
  });
}
