import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/services/delivery/queue_protocol.dart';
import 'package:circle_x/data/services/delivery/queue_worker_entrypoint.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';

import '../support/fakes.dart';

Future<void> pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ReceivePort fromWorker;
  late ReceivePort handshake;
  late SendPort toWorker;
  late List<Map<String, Object?>> messages;

  setUp(() async {
    messages = [];
    fromWorker = ReceivePort();
    handshake = ReceivePort();
    fromWorker.listen(
        (message) => messages.add(Map<String, Object?>.from(message as Map)));
    queueWorkerMain(QueueWorkerSetup(
        toMain: fromWorker.sendPort, handshake: handshake.sendPort));
    toWorker = await handshake.first as SendPort;
    await pump();
  });
  tearDown(() async {
    toWorker.send(mainShutdown());
    await pump();
    fromWorker.close();
    handshake.close();
  });

  Map<String, Object?> submission(int id,
          [TransportKind transport = TransportKind.lattice]) =>
      buildQueuedSubmission(
              id: id,
              entityId: 'report-$id',
              payload: 'signed:$id',
              transport: transport)
          .toMap();
  List<Map<String, Object?>> ofType(String type) =>
      messages.where((m) => m['type'] == type).toList();
  List<Object?> executed() => ofType(QueueWireType.workerExecute)
      .map((m) => m['submissionId'])
      .toList();
  List<Object?> deleted() =>
      ofType(QueueWireType.workerDelete).map((m) => m['submissionId']).toList();

  Future<void> finish(int id) async {
    toWorker.send(mainExecuteResult(submissionId: id, success: true));
    await pump();
    toWorker.send(mainDeleteResult(submissionId: id, success: true));
    await pump();
  }

  test('handshake announces readiness and ignores unrecognized messages',
      () async {
    expect(ofType(QueueWireType.workerReady), hasLength(1));
    toWorker.send('garbage');
    toWorker.send({'type': 'future.type'});
    await pump();
    expect(ofType(QueueWireType.workerLog), hasLength(2));
  });

  test('restart immediately executes both transport queues without UI',
      () async {
    toWorker
        .send(mainHello([submission(1), submission(2, TransportKind.mesh)]));
    await pump();
    expect(executed(), [1, 2]);
    expect(messages.any((m) => '${m['type']}'.contains('prompt')), isFalse);
    expect(
        (ofType(QueueWireType.workerExecute).first['submission']
            as Map)['payload'],
        'signed:1');
  });

  test('new persisted rows are retried on a probe automatically', () async {
    toWorker.send(mainEnqueue(submission(1)));
    await pump();
    expect(executed(), isEmpty);
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1]);
    expect(deleted(), isEmpty);
  });

  test('repeated probes and tracking never duplicate an in-flight send',
      () async {
    toWorker.send(mainHello([submission(1)]));
    toWorker.send(mainEnqueue(submission(1)));
    toWorker.send(mainProbe());
    toWorker.send(mainOutcome(transport: 'lattice', success: true));
    await pump();
    expect(executed(), [1]);
    await finish(1);
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1]);
    expect(deleted(), [1]);
  });

  test('successful send waits for durable deletion before draining next row',
      () async {
    toWorker.send(mainHello([submission(1), submission(2), submission(3)]));
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 1, success: true));
    await pump();
    expect(deleted(), [1]);
    expect(executed(), [1]);
    toWorker.send(mainDeleteResult(submissionId: 1, success: true));
    await pump();
    expect(executed(), [1, 2]);
    await finish(2);
    await finish(3);
    expect(executed(), [1, 2, 3]);
    expect(deleted(), [1, 2, 3]);
  });

  test('failed delivery remains parked and uses exponential probe backoff',
      () async {
    toWorker.send(mainHello([submission(1)]));
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 1, success: false));
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1, 1]);
    toWorker.send(mainExecuteResult(submissionId: 1, success: false));
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1, 1]);
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1, 1, 1]);
    expect(deleted(), isEmpty);
  });

  test('retry wake and confirmed connectivity bypass backoff', () async {
    toWorker.send(mainHello([submission(1)]));
    await pump();
    for (var i = 0; i < 3; i++) {
      toWorker.send(mainExecuteResult(submissionId: 1, success: false));
      toWorker.send(mainRetryNow());
      await pump();
    }
    expect(executed(), [1, 1, 1, 1]);
    toWorker.send(mainExecuteResult(submissionId: 1, success: false));
    toWorker.send(mainOutcome(transport: 'lattice', success: true));
    await pump();
    expect(executed(), hasLength(5));
  });

  test('local deletion failure retries deletion without republishing',
      () async {
    toWorker.send(mainHello([submission(1), submission(2)]));
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 1, success: true));
    await pump();
    toWorker.send(mainDeleteResult(submissionId: 1, success: false));
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1]);
    expect(deleted(), [1, 1]);
    toWorker.send(mainDeleteResult(submissionId: 1, success: true));
    await pump();
    expect(executed(), [1, 2]);
  });

  test('duplicate and unknown execution or deletion results are ignored',
      () async {
    toWorker.send(mainHello([submission(1)]));
    await pump();
    toWorker.send(mainDeleteResult(submissionId: 1, success: true));
    toWorker.send(mainExecuteResult(submissionId: 99, success: true));
    toWorker.send(mainDeleteResult(submissionId: 99, success: true));
    await pump();
    expect(deleted(), isEmpty);
    toWorker.send(mainExecuteResult(submissionId: 1, success: true));
    toWorker.send(mainExecuteResult(submissionId: 1, success: true));
    await pump();
    expect(deleted(), [1]);
    toWorker.send(mainDeleteResult(submissionId: 1, success: true));
    toWorker.send(mainDeleteResult(submissionId: 1, success: true));
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [1]);
  });

  List<Map<String, Object?>> sendNowResults() =>
      ofType(QueueWireType.workerSendNowResult);

  test('send now runs a row stuck behind an in-flight head of its transport',
      () async {
    toWorker.send(mainHello([submission(1), submission(4)]));
    await pump();
    expect(executed(), [1]);
    toWorker.send(mainSendNow(4));
    await pump();
    expect(executed(), [1, 4]);
    expect(sendNowResults(), isEmpty);
    await finish(4);
    expect(sendNowResults().single, containsPair('delivered', true));
    expect(sendNowResults().single['submissionId'], 4);
    expect(executed(), [1, 4]);
  });

  test('send now ignores backoff and reports a failed attempt', () async {
    toWorker.send(mainHello([submission(2, TransportKind.mesh)]));
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 2, success: false));
    toWorker.send(mainProbe());
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 2, success: false));
    toWorker.send(mainProbe());
    await pump();
    expect(executed(), [2, 2]);
    toWorker.send(mainSendNow(2));
    await pump();
    expect(executed(), [2, 2, 2]);
    toWorker.send(mainExecuteResult(submissionId: 2, success: false));
    await pump();
    expect(sendNowResults().single, containsPair('delivered', false));
    expect(deleted(), isEmpty);
  });

  test('send now on a row already in flight waits for that attempt', () async {
    toWorker.send(mainHello([submission(1)]));
    await pump();
    toWorker.send(mainSendNow(1));
    await pump();
    expect(executed(), [1]);
    await finish(1);
    expect(sendNowResults().single, containsPair('delivered', true));
    expect(executed(), [1]);
  });

  test('send now on a row that already left the queue reports it delivered',
      () async {
    toWorker.send(mainHello([submission(1)]));
    await pump();
    await finish(1);
    toWorker.send(mainSendNow(1));
    await pump();
    expect(sendNowResults().single, containsPair('delivered', true));
    expect(executed(), [1]);
  });

  test('a failed transport leaves the other transport free to drain', () async {
    toWorker
        .send(mainHello([submission(1), submission(2, TransportKind.mesh)]));
    await pump();
    toWorker.send(mainExecuteResult(submissionId: 1, success: false));
    await finish(2);
    expect(executed(), [1, 2]);
    expect(deleted(), [2]);
  });
}
