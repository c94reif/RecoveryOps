import 'dart:isolate';

import 'package:ivy_pulse/data/services/queue_protocol.dart';

class QueueWorkerSetup {
  final SendPort toMain;
  final SendPort handshake;

  const QueueWorkerSetup({required this.toMain, required this.handshake});
}

/// The queue's rules, run off the UI isolate so a transport that hangs never
/// stalls an operator mid walk-around.
///
/// This side owns no database, no network and no UI: the main isolate performs
/// every send, prompt and delete and reports the result back. Lattice and mesh
/// are tracked independently because either leg can be down while the other
/// carries traffic, and a leg only drains one submission at a time so the
/// operator is asked about them in the order they were parked.
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

  void log(String message) {
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
    final list = pending[transport]!;
    if (list.isEmpty) return;
    final next = list.first;
    final id = next['id'] as int;
    draining[transport] = true;
    inFlight[id] = InFlight(transport: transport, submission: next);
    setup.toMain.send(workerPrompt(submissionId: id, submission: next));
  }

  /// Retries every leg that has a backlog, using the oldest parked
  /// submission as the probe — the same rule the main-thread worker follows.
  /// The operator is not prompted first: they already chose to send this one,
  /// and if it lands it is delivered rather than merely proven deliverable.
  void onProbe() {
    for (final transport in pending.keys) {
      if (draining[transport] == true) continue;
      final list = pending[transport]!;
      if (list.isEmpty) continue;

      final next = list.first;
      final id = next['id'] as int;
      draining[transport] = true;
      inFlight[id] = InFlight(transport: transport, submission: next)
        ..answered = true;
      setup.toMain.send(workerExecute(submissionId: id, submission: next));
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
    // One answer per prompt. Without this a repeated "send" emits a second
    // execute and the same PMCS goes out twice.
    if (entry.answered) return;
    entry.answered = true;
    if (send) {
      setup.toMain.send(
        workerExecute(submissionId: submissionId, submission: entry.submission),
      );
    } else {
      pending[entry.transport]!
          .removeWhere((s) => (s['id'] as int) == submissionId);
      inFlight.remove(submissionId);
      draining[entry.transport] = false;
      setup.toMain.send(workerDelete(submissionId));
      requestNextPrompt(entry.transport);
    }
  }

  /// Nobody was on screen to answer. Unwind the prompt and leave the
  /// submission parked — the next outcome or resume offers it again.
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
      pending[transport]!.removeWhere((s) => (s['id'] as int) == submissionId);
      connected[transport] = true;
      setup.toMain.send(workerDelete(submissionId));
      requestNextPrompt(transport);
    } else {
      connected[transport] = false;
    }
  }

  fromMain.listen((message) {
    if (message is! Map) {
      log('worker: unexpected message $message');
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
        log('worker: resumed ${resumed.length} pending');
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
        log('worker: unknown type $type');
    }
  });

  setup.toMain.send(workerReady());
}

class InFlight {
  final String transport;
  final Map<String, Object?> submission;

  /// Guards against a second answer to the same prompt re-sending the PMCS.
  bool answered = false;

  InFlight({required this.transport, required this.submission});
}
