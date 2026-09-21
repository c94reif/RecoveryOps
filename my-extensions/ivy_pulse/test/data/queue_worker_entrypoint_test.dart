import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/queue_protocol.dart';
import 'package:ivy_pulse/data/services/queue_worker_entrypoint.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';

import '../support/fakes.dart';

/// Lets the port events the worker sent reach the test's listener.
Future<void> pump() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ReceivePort fromWorker;
  late ReceivePort handshake;
  late SendPort toWorker;
  late List<Map<String, Object?>> messages;

  // The state machine is driven in-process: spawning a real isolate adds
  // nothing to test but flake, and every message crosses a SendPort either way.
  // `mainShutdown` is never sent from here — it calls `Isolate.current.kill()`,
  // which would take the test runner with it.
  setUp(() async {
    messages = [];
    fromWorker = ReceivePort();
    handshake = ReceivePort();
    fromWorker.listen(
      (message) => messages.add(Map<String, Object?>.from(message as Map)),
    );
    queueWorkerMain(
      QueueWorkerSetup(
        toMain: fromWorker.sendPort,
        handshake: handshake.sendPort,
      ),
    );
    toWorker = await handshake.first as SendPort;
    await pump();
  });

  tearDown(() {
    fromWorker.close();
    handshake.close();
  });

  Map<String, Object?> submission({
    required int id,
    String payload = 'encoded:a',
    TransportKind transport = TransportKind.lattice,
  }) =>
      buildQueuedSubmission(id: id, payload: payload, transport: transport)
          .toMap();

  List<Map<String, Object?>> ofType(String type) =>
      messages.where((m) => m['type'] == type).toList();

  List<Map<String, Object?>> prompts() => ofType(QueueWireType.workerPrompt);
  List<Map<String, Object?>> executes() => ofType(QueueWireType.workerExecute);
  List<Map<String, Object?>> deletes() => ofType(QueueWireType.workerDelete);

  List<Object?> idsOf(List<Map<String, Object?>> found) =>
      found.map((m) => m['submissionId']).toList();

  List<String> logs() => ofType(QueueWireType.workerLog)
      .map((m) => m['message'] as String)
      .toList();

  group('handshake', () {
    test('hands the main side a port and announces it is ready', () async {
      expect(ofType(QueueWireType.workerReady), hasLength(1));
    });

    test('logs a message it cannot read instead of dying on it', () async {
      toWorker.send('garbage');
      await pump();

      expect(logs().single, contains('unexpected message'));
      expect(ofType(QueueWireType.workerPrompt), isEmpty);
    });

    test('logs an unknown message type and keeps listening', () async {
      toWorker.send(<String, Object?>{'type': 'main.somethingNew'});
      toWorker.send(mainEnqueue(submission(id: 1)));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(logs().single, contains('unknown type'));
      expect(prompts(), hasLength(1));
    });
  });

  group('resuming a backlog', () {
    test('takes on the rows the main side read off disk', () async {
      toWorker.send(
        mainHello([submission(id: 1), submission(id: 2)]),
      );
      await pump();

      expect(logs().single, 'worker: resumed 2 pending');
    });

    test('offers a resumed row once its leg reports a success', () async {
      toWorker.send(mainHello([submission(id: 7, payload: 'encoded:old')]));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(prompts().single['submissionId'], 7);
      expect(
        (prompts().single['submission']! as Map)['payload'],
        'encoded:old',
      );
    });

    test('does not offer a resumed row before anything proves the leg is up',
        () async {
      toWorker.send(mainHello([submission(id: 1)]));
      await pump();

      expect(prompts(), isEmpty);
    });
  });

  group('transport outcomes', () {
    test('a failing outcome parks the leg and asks the operator nothing',
        () async {
      toWorker.send(mainEnqueue(submission(id: 1)));
      toWorker.send(mainOutcome(transport: 'lattice', success: false));
      await pump();

      expect(prompts(), isEmpty);
      expect(deletes(), isEmpty);
    });

    test('an enqueue on its own parks the leg silently', () async {
      toWorker.send(mainEnqueue(submission(id: 1)));
      await pump();

      expect(messages.where((m) => m['type'] != QueueWireType.workerReady),
          isEmpty);
    });

    test('a succeeding outcome offers the oldest parked submission', () async {
      toWorker.send(mainEnqueue(submission(id: 1, payload: 'encoded:oldest')));
      toWorker.send(mainEnqueue(submission(id: 2, payload: 'encoded:newer')));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(prompts(), hasLength(1));
      expect(prompts().single['submissionId'], 1);
    });

    test('a mesh success never offers a Lattice submission', () async {
      toWorker.send(mainEnqueue(submission(id: 1, payload: 'encoded:lattice')));
      toWorker.send(
        mainEnqueue(
          submission(
            id: 2,
            payload: 'encoded:mesh',
            transport: TransportKind.mesh,
          ),
        ),
      );
      toWorker.send(mainOutcome(transport: 'mesh', success: true));
      await pump();

      expect(idsOf(prompts()), [2]);
    });

    test('a second success while a prompt is out does not double-prompt',
        () async {
      toWorker.send(mainEnqueue(submission(id: 1)));
      toWorker.send(mainEnqueue(submission(id: 2)));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(prompts(), hasLength(1));
    });
  });

  group('prompt responses', () {
    setUp(() async {
      toWorker.send(mainEnqueue(submission(id: 1, payload: 'encoded:a')));
      toWorker.send(mainEnqueue(submission(id: 2, payload: 'encoded:b')));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();
    });

    test('send asks the main side to execute the stored submission', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: true));
      await pump();

      expect(executes().single['submissionId'], 1);
      expect(
        (executes().single['submission']! as Map)['payload'],
        'encoded:a',
      );
    });

    test('send drops nothing until the execute reports back', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: true));
      await pump();

      expect(deletes(), isEmpty);
      expect(prompts(), hasLength(1));
    });

    test('discard deletes the row without executing it', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: false));
      await pump();

      expect(idsOf(deletes()), [1]);
      expect(executes(), isEmpty);
    });

    test('discard moves straight on to the next parked submission', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: false));
      await pump();

      expect(idsOf(prompts()), [1, 2]);
    });

    test('a response for a submission it never offered is ignored', () async {
      toWorker.send(mainPromptResponse(submissionId: 99, send: true));
      await pump();

      expect(executes(), isEmpty);
      expect(deletes(), isEmpty);
    });

    test('a repeated discard does not delete the row twice', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: false));
      await pump();
      toWorker.send(mainPromptResponse(submissionId: 1, send: false));
      await pump();

      expect(idsOf(deletes()), [1]);
    });

    test('a repeated send executes the submission only once', () async {
      toWorker.send(mainPromptResponse(submissionId: 1, send: true));
      await pump();
      toWorker.send(mainPromptResponse(submissionId: 1, send: true));
      await pump();

      // One answer per prompt: a duplicated response must not put the same
      // PMCS on the wire twice.
      expect(idsOf(executes()), [1]);
    });

    test('a probe retries a down leg with its oldest parked submission',
        () async {
      // Regression: a backlog restored at start-up used to sit untouched
      // until the operator happened to submit another PMCS on the same leg.
      toWorker.send(mainProbe());
      await pump();

      expect(idsOf(executes()), [1]);
      // Probed, not prompted — the operator already chose to send this one.
      expect(prompts().length, greaterThanOrEqualTo(1));
    });

    test('a deferred prompt unwinds the drain and leaves the row parked',
        () async {
      toWorker.send(mainPromptDeferred(1));
      await pump();

      expect(executes(), isEmpty);
      expect(deletes(), isEmpty);

      // The leg is free again, so the next outcome re-offers the same row
      // rather than the transport sitting wedged.
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(idsOf(prompts()).last, 1);
    });
  });

  group('execute results', () {
    setUp(() async {
      toWorker.send(mainEnqueue(submission(id: 1, payload: 'encoded:a')));
      toWorker.send(mainEnqueue(submission(id: 2, payload: 'encoded:b')));
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();
      toWorker.send(mainPromptResponse(submissionId: 1, send: true));
      await pump();
    });

    test('a send that landed deletes the row', () async {
      toWorker.send(mainExecuteResult(submissionId: 1, success: true));
      await pump();

      expect(idsOf(deletes()), [1]);
    });

    test('a send that landed moves on to the next parked submission', () async {
      toWorker.send(mainExecuteResult(submissionId: 1, success: true));
      await pump();

      expect(idsOf(prompts()), [1, 2]);
    });

    test('a send that failed keeps the row and stops the drain', () async {
      toWorker.send(mainExecuteResult(submissionId: 1, success: false));
      await pump();

      expect(deletes(), isEmpty);
      expect(prompts(), hasLength(1));
    });

    test('a leg that comes back after a failed send re-offers the same row',
        () async {
      toWorker.send(mainExecuteResult(submissionId: 1, success: false));
      await pump();
      toWorker.send(mainOutcome(transport: 'lattice', success: true));
      await pump();

      expect(idsOf(prompts()), [1, 1]);
    });

    test('a result for a submission it never executed is ignored', () async {
      toWorker.send(mainExecuteResult(submissionId: 99, success: true));
      await pump();

      expect(deletes(), isEmpty);
      expect(prompts(), hasLength(1));
    });

    test('drains the whole backlog one at a time while the leg holds up',
        () async {
      toWorker.send(mainEnqueue(submission(id: 3, payload: 'encoded:c')));
      await pump();

      for (var i = 0; i < 3; i++) {
        final id = prompts().last['submissionId']! as int;
        toWorker.send(mainPromptResponse(submissionId: id, send: true));
        await pump();
        toWorker.send(mainExecuteResult(submissionId: id, success: true));
        await pump();
      }

      expect(idsOf(deletes()), [1, 2, 3]);
      expect(idsOf(prompts()), [1, 2, 3]);
    });

    test('a failed send on one leg leaves the other leg free to drain',
        () async {
      toWorker.send(mainExecuteResult(submissionId: 1, success: false));
      toWorker.send(
        mainEnqueue(
          submission(
            id: 5,
            payload: 'encoded:mesh',
            transport: TransportKind.mesh,
          ),
        ),
      );
      toWorker.send(mainOutcome(transport: 'mesh', success: true));
      await pump();

      expect(idsOf(prompts()), [1, 5]);
    });
  });
}
