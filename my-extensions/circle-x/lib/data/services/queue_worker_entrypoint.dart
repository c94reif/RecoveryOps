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
  final inFlight = <int, InFlight>{};
  final failures = <String, int>{};
  final skipProbes = <String, int>{};
  final delivered = <int>{};

  void requestNext(String transport) {
    if (inFlight.values.any((entry) => entry.transport == transport)) return;
    final transportQueue = pending[transport]!;
    if (transportQueue.isEmpty) return;
    final next = transportQueue.first;
    final id = next['id'] as int;
    inFlight[id] = InFlight(transport: transport)
      ..awaitingDelete = delivered.contains(id);
    setup.toMain.send(delivered.contains(id)
        ? workerDelete(id)
        : workerExecute(submissionId: id, submission: next));
  }

  void enqueueLocal(Map<String, Object?> submission) {
    final queue = pending[submission['transport'] as String]!;
    if (!queue.any((row) => row['id'] == submission['id'])) {
      queue.add(submission);
    }
  }

  void backOff(String transport) {
    final attempts = ((failures[transport] ?? 0) + 1).clamp(1, 5);
    failures[transport] = attempts;
    skipProbes[transport] = (1 << (attempts - 1)) - 1;
  }

  void onProbe() {
    for (final transport in pending.keys) {
      final skipped = skipProbes[transport] ?? 0;
      if (skipped > 0) {
        skipProbes[transport] = skipped - 1;
      } else {
        requestNext(transport);
      }
    }
  }

  void onExecuteResult(int id, bool success) {
    final entry = inFlight[id];
    if (entry == null || entry.awaitingDelete) return;
    if (success) {
      delivered.add(id);
      entry.awaitingDelete = true;
      setup.toMain.send(workerDelete(id));
    } else {
      inFlight.remove(id);
      backOff(entry.transport);
    }
  }

  void onDeleteResult(int id, bool success) {
    final entry = inFlight[id];
    if (entry == null || !entry.awaitingDelete) return;
    inFlight.remove(id);
    if (!success) {
      backOff(entry.transport);
      return;
    }
    pending[entry.transport]!.removeWhere((row) => row['id'] == id);
    delivered.remove(id);
    failures.remove(entry.transport);
    skipProbes.remove(entry.transport);
    requestNext(entry.transport);
  }

  fromMain.listen((message) {
    if (message is! Map) {
      setup.toMain.send(workerLog('worker: unexpected message $message'));
      return;
    }
    final map = Map<String, Object?>.from(message);
    final type = map['type'] as String?;
    switch (type) {
      case QueueWireType.mainHello:
        final resumed = (map['resumed'] as List).cast<Map<String, Object?>>();
        for (final submission in resumed) {
          enqueueLocal(submission);
        }
        setup.toMain
            .send(workerLog('worker: resumed ${resumed.length} pending'));
        onProbe();
        break;
      case QueueWireType.mainEnqueue:
        enqueueLocal(map['submission'] as Map<String, Object?>);
        break;
      case QueueWireType.mainOutcome:
        final transport = map['transport'] as String;
        if (map['success'] as bool) {
          failures.remove(transport);
          skipProbes.remove(transport);
          requestNext(transport);
        }
        break;
      case QueueWireType.mainExecuteResult:
        onExecuteResult(map['submissionId'] as int, map['success'] as bool);
        break;
      case QueueWireType.mainDeleteResult:
        onDeleteResult(map['submissionId'] as int, map['success'] as bool);
        break;
      case QueueWireType.mainRetryNow:
        failures.clear();
        skipProbes.clear();
        onProbe();
        break;
      case QueueWireType.mainProbe:
        onProbe();
        break;
      case QueueWireType.mainShutdown:
        fromMain.close();
        break;
      default:
        setup.toMain.send(workerLog('worker: unknown type $type'));
    }
  });

  setup.toMain.send(workerReady());
}

class InFlight {
  final String transport;
  bool awaitingDelete = false;

  InFlight({required this.transport});
}
