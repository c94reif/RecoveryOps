import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/services/queue_protocol.dart';
import 'package:ivy_pulse/data/services/queue_worker_entrypoint.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';

/// Runs the queue's state machine on a worker isolate and keeps every side
/// effect — database, transports, operator prompt — on the main isolate.
///
/// Native builds only; the web build gets MainThreadQueueWorker instead.
class IsolateQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueuePromptStrategy promptStrategy;
  final SnackBarService snackBarService;

  final Duration probeInterval;

  Isolate? isolate;
  Timer? probeTimer;
  SendPort? toWorker;
  ReceivePort? fromWorker;
  Completer<void>? readyCompleter;

  IsolateQueueWorker({
    required this.repository,
    required this.entityPort,
    required this.meshPort,
    required this.promptStrategy,
    SnackBarService? snackBarService,
    Duration? probeInterval,
  })  : snackBarService = snackBarService ?? SnackBarService.instance,
        probeInterval = probeInterval ?? AppConstants.transportProbeInterval;

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
      debugName: 'ivy_pulse.queue_worker',
    );

    final handshakeFirst = await handshakePort.first;
    handshakePort.close();
    toWorker = handshakeFirst as SendPort;

    fromWorkerPort.listen(handleWorkerMessage);

    await readyCompleter!.future;

    toWorker!.send(
      mainHello(resumed.map((s) => s.toMap()).toList()),
    );
  }

  @override
  Future<void> stop() async {
    probeTimer?.cancel();
    probeTimer = null;
    toWorker?.send(mainShutdown());
    fromWorker?.close();
    isolate?.kill(priority: Isolate.beforeNextEvent);
    isolate = null;
    toWorker = null;
    fromWorker = null;
    readyCompleter = null;
  }

  @override
  Future<void> enqueue(QueuedSubmission submission) async {
    final stored = await repository.insert(submission);
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

  @override
  Future<int> pendingCount() => repository.count();

  void handleWorkerMessage(dynamic message) {
    if (message is! Map) {
      debugPrint('[IvyPulse] QueueWorker: unexpected message: $message');
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
          map['submissionId'] as int,
          QueuedSubmission.fromMap(
            Map<String, Object?>.from(map['submission'] as Map),
          ),
        );
        break;
      case QueueWireType.workerPrompt:
        handlePrompt(
          map['submissionId'] as int,
          QueuedSubmission.fromMap(
            Map<String, Object?>.from(map['submission'] as Map),
          ),
        );
        break;
      case QueueWireType.workerDelete:
        handleDelete(map['submissionId'] as int);
        break;
      case QueueWireType.workerLog:
        debugPrint('[IvyPulse] QueueWorker: ${map['message']}');
        break;
      default:
        debugPrint('[IvyPulse] QueueWorker: unknown message type: $type');
    }
  }

  Future<void> handleExecute(
    int submissionId,
    QueuedSubmission submission,
  ) async {
    final position = LatLng(submission.latitude, submission.longitude);
    bool success;
    switch (submission.transport) {
      case TransportKind.lattice:
        // The stored payload is re-sent verbatim: the session it came from may
        // have been continued or abandoned since it was parked.
        success = await entityPort.publishEncodedReport(
          entityId: submission.entityId,
          payload: submission.payload,
          position: position,
        );
        break;
      case TransportKind.mesh:
        success = await meshPort.broadcastEncodedReport(submission.payload);
        break;
    }

    snackBarService.enqueue(
      '${submission.transport.displayName}: '
      '${success ? 'sent (queued)' : 'still FAILED'}',
      isError: !success,
    );

    toWorker?.send(
      mainExecuteResult(submissionId: submissionId, success: success),
    );
  }

  Future<void> handlePrompt(
    int submissionId,
    QueuedSubmission submission,
  ) async {
    final send = await promptStrategy.ask(submission);
    if (send == null) {
      // No UI was listening. Tell the worker to unwind this prompt and leave
      // the submission parked rather than answering on the operator's behalf.
      toWorker?.send(mainPromptDeferred(submissionId));
      return;
    }
    toWorker?.send(
      mainPromptResponse(submissionId: submissionId, send: send),
    );
  }

  Future<void> handleDelete(int submissionId) async {
    try {
      await repository.deleteById(submissionId);
    } catch (e) {
      debugPrint(
        '[IvyPulse] QueueWorker: delete failed for $submissionId: $e',
      );
    }
  }
}
