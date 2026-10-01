import 'dart:isolate';

import 'package:circle_x/data/services/queue_protocol.dart';

class QueueWorkerSetup {
  final SendPort toMain;
  final SendPort handshake;

  const QueueWorkerSetup({required this.toMain, required this.handshake});
}

void queueWorkerMain(QueueWorkerSetup setup) {
  final fromMain = ReceivePort();
  setup.handshake.send(fromMain.sendPort);

  final pending = <String, List<Map<String, Object?>>>{
    'lattice': [],
    'mesh': [],
  };
  final connected = <String, bool>{
    'lattice': true,
    'mesh': true,
  };
  final draining = <String, bool>{
    'lattice': false,
    'mesh': false,
  };
  final inFlight = <int, InFlight>{};

  void sendLogMessage(String message) {
    setup.toMain.send(workerLog(message));
  }

  void enqueueLocal(Map<String, Object?> submission) {
    final transport = submission['transport'] as String;
    pending[transport]!.add(submission);
    connected[transport] = false;
  }

  void requestNextPrompt(String transport) {
    if (draining[transport] == true) return;
    if (connected[transport] != true) return;
    final transportQueue = pending[transport]!;
    if (transportQueue.isEmpty) return;
    final nextSubmission = transportQueue.first;
    final submissionId = nextSubmission['id'] as int;
    draining[transport] = true;
    inFlight[submissionId] =
        InFlight(transport: transport, submission: nextSubmission);
    setup.toMain.send(
        workerPrompt(submissionId: submissionId, submission: nextSubmission));
  }

  void onProbe() {
    for (final transport in pending.keys) {
      if (draining[transport] == true) continue;
      final transportQueue = pending[transport]!;
      if (transportQueue.isEmpty) continue;
      if (connected[transport] == true) {
        requestNextPrompt(transport);
        continue;
      }

      final nextSubmission = transportQueue.first;
      final submissionId = nextSubmission['id'] as int;
      draining[transport] = true;
      inFlight[submissionId] =
          InFlight(transport: transport, submission: nextSubmission)
            ..answered = true;
      setup.toMain.send(workerExecute(
          submissionId: submissionId, submission: nextSubmission));
    }
  }

  void onOutcome(String transport, bool success) {
    if (success) {
      connected[transport] = true;
      requestNextPrompt(transport);
    } else {
      connected[transport] = false;
    }
  }

  void onPromptResponse(int submissionId, bool send) {
    final entry = inFlight[submissionId];
    if (entry == null) return;
    if (entry.answered) return;
    entry.answered = true;
    if (send) {
      setup.toMain.send(
        workerExecute(submissionId: submissionId, submission: entry.submission),
      );
    } else {
      pending[entry.transport]!.removeWhere(
          (submission) => (submission['id'] as int) == submissionId);
      inFlight.remove(submissionId);
      draining[entry.transport] = false;
      setup.toMain.send(workerDelete(submissionId));
      requestNextPrompt(entry.transport);
    }
  }

  void onPromptDeferred(int submissionId) {
    final entry = inFlight.remove(submissionId);
    if (entry == null) return;
    draining[entry.transport] = false;
  }

  void onExecuteResult(int submissionId, bool success) {
    final entry = inFlight.remove(submissionId);
    if (entry == null) return;
    final transport = entry.transport;
    draining[transport] = false;
    if (success) {
      pending[transport]!.removeWhere(
          (submission) => (submission['id'] as int) == submissionId);
      connected[transport] = true;
      setup.toMain.send(workerDelete(submissionId));
      requestNextPrompt(transport);
    } else {
      connected[transport] = false;
    }
  }

  fromMain.listen((message) {
    if (message is! Map) {
      sendLogMessage('worker: unexpected message $message');
      return;
    }
    final map = Map<String, Object?>.from(message);
    final type = map['type'] as String?;
    switch (type) {
      case QueueWireType.mainHello:
        final resumed = (map['resumed'] as List).cast<Map<String, Object?>>();
        for (final submission in resumed) {
          final transport = submission['transport'] as String;
          pending[transport]!.add(submission);
        }
        sendLogMessage('worker: resumed ${resumed.length} pending');
        break;
      case QueueWireType.mainEnqueue:
        final submission = map['submission'] as Map<String, Object?>;
        enqueueLocal(submission);
        break;
      case QueueWireType.mainOutcome:
        onOutcome(map['transport'] as String, map['success'] as bool);
        break;
      case QueueWireType.mainPromptResponse:
        onPromptResponse(map['submissionId'] as int, map['send'] as bool);
        break;
      case QueueWireType.mainPromptDeferred:
        onPromptDeferred(map['submissionId'] as int);
        break;
      case QueueWireType.mainExecuteResult:
        onExecuteResult(map['submissionId'] as int, map['success'] as bool);
        break;
      case QueueWireType.mainProbe:
        onProbe();
        break;
      case QueueWireType.mainShutdown:
        fromMain.close();
        Isolate.current.kill();
        break;
      default:
        sendLogMessage('worker: unknown type $type');
    }
  });

  setup.toMain.send(workerReady());
}

class InFlight {
  final String transport;
  final Map<String, Object?> submission;

  bool answered = false;

  InFlight({required this.transport, required this.submission});
}
