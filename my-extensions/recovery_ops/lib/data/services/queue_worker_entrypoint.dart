import 'dart:isolate';

import 'package:recovery_ops/data/services/queue_protocol.dart';

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

  void log(String message) {
    setup.toMain.send(workerLog(message));
  }

  void enqueueLocal(Map<String, Object?> request) {
    final transport = request['transport'] as String;
    pending[transport]!.add(request);
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
    inFlight[id] = InFlight(transport: transport, request: next);
    setup.toMain.send(workerPrompt(requestId: id, request: next));
  }

  void onOutcome(String transport, bool success) {
    if (success) {
      connected[transport] = true;
      requestNextPrompt(transport);
    } else {
      connected[transport] = false;
    }
  }

  void onPromptResponse(int requestId, bool send) {
    final entry = inFlight[requestId];
    if (entry == null) return;
    if (send) {
      setup.toMain.send(
        workerExecute(requestId: requestId, request: entry.request),
      );
    } else {
      pending[entry.transport]!
          .removeWhere((r) => (r['id'] as int) == requestId);
      inFlight.remove(requestId);
      draining[entry.transport] = false;
      setup.toMain.send(workerDelete(requestId));
      requestNextPrompt(entry.transport);
    }
  }

  void onExecuteResult(int requestId, bool success) {
    final entry = inFlight.remove(requestId);
    if (entry == null) return;
    final transport = entry.transport;
    draining[transport] = false;
    if (success) {
      pending[transport]!.removeWhere((r) => (r['id'] as int) == requestId);
      connected[transport] = true;
      setup.toMain.send(workerDelete(requestId));
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
        for (final req in resumed) {
          final transport = req['transport'] as String;
          pending[transport]!.add(req);
        }
        log('worker: resumed ${resumed.length} pending');
        break;
      case QueueWireType.mainEnqueue:
        final req = map['request'] as Map<String, Object?>;
        enqueueLocal(req);
        break;
      case QueueWireType.mainOutcome:
        onOutcome(map['transport'] as String, map['success'] as bool);
        break;
      case QueueWireType.mainPromptResponse:
        onPromptResponse(map['requestId'] as int, map['send'] as bool);
        break;
      case QueueWireType.mainExecuteResult:
        onExecuteResult(map['requestId'] as int, map['success'] as bool);
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
  final Map<String, Object?> request;

  const InFlight({required this.transport, required this.request});
}
