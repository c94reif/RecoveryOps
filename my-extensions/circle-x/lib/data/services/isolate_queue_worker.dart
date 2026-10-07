import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/data/services/queue_protocol.dart';
import 'package:circle_x/data/services/queue_worker_entrypoint.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/queue_prompt_strategy.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';

class IsolateQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final UserNotificationSink snackBarService;

  final Duration probeInterval;
  final DeliveryCoordinator delivery;

  Isolate? isolate;
  Timer? probeTimer;
  SendPort? toWorker;
  ReceivePort? fromWorker;
  ReceivePort? _handshakePort;
  Completer<void>? readyCompleter;
  final waitingForStart = <int, QueuedSubmission>{};
  Future<void>? starting;
  int _generation = 0;

  IsolateQueueWorker({
    required this.repository,
    required this.entityPort,
    required this.meshPort,
    // Retained for source compatibility; retries never ask for UI approval.
    QueuePromptStrategy? promptStrategy,
    UserNotificationSink? snackBarService,
    Duration? probeInterval,
    DeliveryCoordinator? delivery,
  })  : delivery = delivery ?? DeliveryCoordinator(),
        snackBarService = snackBarService ?? const SilentNotificationSink(),
        probeInterval = probeInterval ?? AppConstants.transportProbeInterval;

  @override
  Future<void> start() {
    final generation = _generation;
    return starting ??= startWorker().whenComplete(() {
      if (generation == _generation) starting = null;
    });
  }

  Future<void> startWorker() async {
    if (isolate != null) return;

    final generation = _generation;
    final resumed = await repository.getAll();
    if (generation != _generation) return;
    for (final submission in resumed) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.queued,
          withdrawal: submission.isWithdrawal);
      if (submission.isWithdrawal) delivery.suppressReport(submission.entityId);
    }

    final handshakePort = ReceivePort();
    _handshakePort = handshakePort;
    final handshaking = handshakePort.first.then<SendPort?>(
      (message) => message as SendPort,
      onError: (Object error) {
        if (generation != _generation) return null;
        throw error;
      },
    );
    final fromWorkerPort = ReceivePort();
    fromWorker = fromWorkerPort;
    final ready = Completer<void>();
    readyCompleter = ready;

    final setup = QueueWorkerSetup(
      toMain: fromWorkerPort.sendPort,
      handshake: handshakePort.sendPort,
    );

    final spawned = await Isolate.spawn<QueueWorkerSetup>(
      queueWorkerMain,
      setup,
      debugName: 'circle-x.queue_worker',
    );

    if (generation != _generation) {
      spawned.kill(priority: Isolate.immediate);
      handshakePort.close();
      fromWorkerPort.close();
      return;
    }
    isolate = spawned;
    final workerPort = await handshaking;
    handshakePort.close();
    if (generation != _generation || workerPort == null) return;
    _handshakePort = null;
    toWorker = workerPort;
    fromWorkerPort.listen((message) {
      if (generation == _generation) handleWorkerMessage(message);
    });

    await ready.future;
    if (generation != _generation) return;

    toWorker!.send(
      mainHello(resumed.map((submission) => submission.toMap()).toList()),
    );
    final resumedIds = resumed.map((submission) => submission.id).toSet();
    for (final row in waitingForStart.values) {
      if (!resumedIds.contains(row.id)) {
        toWorker!.send(mainEnqueue(row.toMap()));
      }
    }
    waitingForStart.clear();
    probeTimer =
        Timer.periodic(probeInterval, (_) => toWorker?.send(mainProbe()));
  }

  @override
  Future<void> stop() async {
    _generation++;
    starting = null;
    if (readyCompleter != null && !readyCompleter!.isCompleted) {
      readyCompleter!.complete();
    }
    waitingForStart.clear();
    _handshakePort?.close();
    _handshakePort = null;
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
    trackPersisted(stored);
    if (stored.isWithdrawal) return;
    snackBarService.enqueue(
      '${stored.transport.displayName} unreachable — '
      'queued, will send on reconnect',
      isError: true,
    );
  }

  @override
  void trackPersisted(QueuedSubmission submission) {
    if (submission.isWithdrawal) delivery.suppressReport(submission.entityId);
    if (probeTimer == null) {
      waitingForStart[submission.id!] = submission;
    } else {
      toWorker!.send(mainEnqueue(submission.toMap()));
    }
    delivery.queueChanged();
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
  Future<void> retryNow() async => toWorker?.send(mainRetryNow());

  @override
  Future<int> pendingCount() => repository.count();

  void handleWorkerMessage(dynamic message) {
    if (message is! Map) {
      debugPrint('[CircleX] QueueWorker: unexpected message: $message');
      return;
    }
    final map = Map<String, Object?>.from(message);
    final type = map['type'] as String?;
    switch (type) {
      case QueueWireType.workerReady:
        readyCompleter?.complete();
        break;
      case QueueWireType.workerExecute:
        final workerPort = toWorker;
        unawaited(handleExecute(
          map['submissionId'] as int,
          QueuedSubmission.fromMap(
            Map<String, Object?>.from(map['submission'] as Map),
          ),
        ).catchError((Object error) {
          debugPrint('[CircleX] Queued execution failed: $error');
          workerPort?.send(mainExecuteResult(
              submissionId: map['submissionId'] as int, success: false));
        }));
        break;
      case QueueWireType.workerDelete:
        unawaited(handleDelete(map['submissionId'] as int));
        break;
      case QueueWireType.workerLog:
        debugPrint('[CircleX] QueueWorker: ${map['message']}');
        break;
      default:
        debugPrint('[CircleX] QueueWorker: unknown message type: $type');
    }
  }

  Future<void> handleExecute(
    int submissionId,
    QueuedSubmission submission,
  ) async {
    final generation = _generation;
    final workerPort = toWorker;
    final source = submission.reviewSourceReportId;
    if (!submission.isWithdrawal &&
        source != null &&
        await delivery.isWithdrawn(source)) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.discarded);
      if (generation == _generation) {
        workerPort?.send(
            mainExecuteResult(submissionId: submissionId, success: true));
      }
      return;
    }
    final success = delivery.status(submission.entityId, submission.transport,
                withdrawal: submission.isWithdrawal) ==
            DeliveryStatus.sent ||
        await delivery.send(submission.entityId, submission.transport,
            () async {
          try {
            if (submission.isWithdrawal) {
              return switch (submission.transport) {
                TransportKind.lattice =>
                  await entityPort.deletePmcsEntity(submission.entityId),
                TransportKind.mesh =>
                  await meshPort.broadcastPmcsDeletion(submission.entityId),
              };
            }
            return switch (submission.transport) {
              TransportKind.lattice => await entityPort.publishEncodedReport(
                  entityId: submission.entityId,
                  payload: submission.payload,
                  position: LatLng(submission.latitude, submission.longitude)),
              TransportKind.mesh =>
                await meshPort.broadcastEncodedReport(submission.payload),
            };
          } catch (error) {
            debugPrint('[CircleX] Queued send failed: $error');
            return false;
          }
        }, queuedOnFailure: true, withdrawal: submission.isWithdrawal);

    if (generation != _generation) return;
    workerPort?.send(
      mainExecuteResult(submissionId: submissionId, success: success),
    );
  }

  Future<void> handleDelete(int submissionId) async {
    final generation = _generation;
    final workerPort = toWorker;
    var success = false;
    try {
      await repository.deleteById(submissionId);
      success = true;
      delivery.queueChanged();
    } catch (error) {
      debugPrint(
          '[CircleX] QueueWorker: delete failed for $submissionId: $error');
    }
    if (generation != _generation) return;
    workerPort
        ?.send(mainDeleteResult(submissionId: submissionId, success: success));
  }
}
