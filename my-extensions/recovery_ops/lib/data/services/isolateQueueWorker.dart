import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/data/services/queueProtocol.dart';
import 'package:recovery_ops/data/services/queueWorkerEntrypoint.dart';
import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';
import 'package:recovery_ops/domain/repositories/queuedRequestsRepo.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';
import 'package:recovery_ops/domain/services/queuePromptStrategy.dart';
import 'package:recovery_ops/domain/services/queueWorkerStrategy.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/presentation/common/widgets/customSnackBar.dart';

class IsolateQueueWorker implements QueueWorkerStrategy {
  final QueuedRequestsRepository repository;
  final RecoveryEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueuePromptStrategy promptStrategy;
  final SnackBarService snackBarService;

  Isolate? isolate;
  SendPort? toWorker;
  ReceivePort? fromWorker;
  Completer<void>? readyCompleter;

  IsolateQueueWorker({
    required this.repository,
    required this.entityPort,
    required this.meshPort,
    required this.promptStrategy,
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance;

  @override
  Future<void> start() async {
    if (isolate != null) return;

    final resumed = await repository.getAll();

    final handshakePort = ReceivePort();
    final fromWorkerPort = ReceivePort();
    fromWorker = fromWorkerPort;
    readyCompleter = Completer<void>();

    final setup = QueueWorkerSetup(
      toMain: fromWorkerPort.sendPort,
      handshake: handshakePort.sendPort,
    );

    isolate = await Isolate.spawn<QueueWorkerSetup>(
      queueWorkerMain,
      setup,
      debugName: 'recovery_ops.queue_worker',
    );

    final handshakeFirst = await handshakePort.first;
    handshakePort.close();
    toWorker = handshakeFirst as SendPort;

    fromWorkerPort.listen(handleWorkerMessage);

    await readyCompleter!.future;

    toWorker!.send(
      mainHello(resumed.map((r) => r.toMap()).toList()),
    );
  }

  @override
  Future<void> stop() async {
    toWorker?.send(mainShutdown());
    fromWorker?.close();
    isolate?.kill(priority: Isolate.beforeNextEvent);
    isolate = null;
    toWorker = null;
    fromWorker = null;
    readyCompleter = null;
  }

  @override
  Future<void> enqueue(QueuedRequest request) async {
    final stored = await repository.insert(request);
    toWorker?.send(mainEnqueue(stored.toMap()));
    snackBarService.enqueue(
      '${stored.transport.displayName} unreachable — '
      'queued, will send on reconnect',
      isError: true,
    );
  }

  @override
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  }) {
    toWorker?.send(
      mainOutcome(transport: transport.wireName, success: success),
    );
  }

  void handleWorkerMessage(dynamic message) {
    if (message is! Map) {
      debugPrint('[QueueWorker] unexpected message: $message');
      return;
    }
    final map = Map<String, Object?>.from(message);
    final type = map['type'] as String?;
    switch (type) {
      case QueueWireType.workerReady:
        readyCompleter?.complete();
        break;
      case QueueWireType.workerExecute:
        handleExecute(
          map['requestId'] as int,
          QueuedRequest.fromMap(
            Map<String, Object?>.from(map['request'] as Map),
          ),
        );
        break;
      case QueueWireType.workerPrompt:
        handlePrompt(
          map['requestId'] as int,
          QueuedRequest.fromMap(
            Map<String, Object?>.from(map['request'] as Map),
          ),
        );
        break;
      case QueueWireType.workerDelete:
        handleDelete(map['requestId'] as int);
        break;
      case QueueWireType.workerLog:
        debugPrint('[QueueWorker] ${map['message']}');
        break;
      default:
        debugPrint('[QueueWorker] unknown message type: $type');
    }
  }

  Future<void> handleExecute(int requestId, QueuedRequest request) async {
    final position = LatLng(request.latitude, request.longitude);
    bool success;
    switch (request.transport) {
      case TransportKind.lattice:
        success = await entityPort.publishRecoveryEntity(
          entityId: request.entityId,
          bumperNumber: request.bumperNumber,
          issue: request.issue,
          typeName: request.recoveryType,
          position: position,
        );
        break;
      case TransportKind.mesh:
        success = await meshPort.broadcastRecoveryRequest(
          entityId: request.entityId,
          bumperNumber: request.bumperNumber,
          issue: request.issue,
          typeName: request.recoveryType,
          position: position,
        );
        break;
    }

    snackBarService.enqueue(
      '${request.transport.displayName}: '
      '${success ? 'sent (queued)' : 'still FAILED'}',
      isError: !success,
    );

    toWorker?.send(
      mainExecuteResult(requestId: requestId, success: success),
    );
  }

  Future<void> handlePrompt(int requestId, QueuedRequest request) async {
    final send = await promptStrategy.ask(request);
    toWorker?.send(
      mainPromptResponse(requestId: requestId, send: send),
    );
  }

  Future<void> handleDelete(int requestId) async {
    try {
      await repository.deleteById(requestId);
    } catch (e) {
      debugPrint('[QueueWorker] delete failed for $requestId: $e');
    }
  }
}
