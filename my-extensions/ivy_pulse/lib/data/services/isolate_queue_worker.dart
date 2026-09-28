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
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/services/user_notification_sink.dart';

class IsolateQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueuePromptStrategy promptStrategy;
  final UserNotificationSink snackBarService;

  final Duration probeInterval;
  final DeliveryCoordinator delivery;

  Isolate? isolate;
  Timer? probeTimer;
  SendPort? toWorker;
  ReceivePort? fromWorker;
  Completer<void>? readyCompleter;
  final waitingForStart = <int, QueuedSubmission>{};
  Future<void>? starting;

  IsolateQueueWorker({
    required this.repository,
    required this.entityPort,
    required this.meshPort,
    required this.promptStrategy,
    UserNotificationSink? snackBarService,
    Duration? probeInterval,
    DeliveryCoordinator? delivery,
  })  : delivery = delivery ?? DeliveryCoordinator(),
        snackBarService = snackBarService ?? const SilentNotificationSink(),
        probeInterval = probeInterval ?? AppConstants.transportProbeInterval;

  @override
  Future<void> start() => starting ??= startWorker().whenComplete(() {
        starting = null;
      });

  Future<void> startWorker() async {
    if (isolate != null) return;

    final resumed = await repository.getAll();
    for (final submission in resumed) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.queued,
          withdrawal: submission.isWithdrawal);
      if (submission.isWithdrawal) delivery.suppressReport(submission.entityId);
    }

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
        unawaited(handleExecute(
          map['submissionId'] as int,
          QueuedSubmission.fromMap(
            Map<String, Object?>.from(map['submission'] as Map),
          ),
        ).catchError((Object error) {
          debugPrint('[IvyPulse] Queued execution failed: $error');
          toWorker?.send(mainExecuteResult(
              submissionId: map['submissionId'] as int, success: false));
        }));
        break;
      case QueueWireType.workerPrompt:
        unawaited(handlePrompt(
          map['submissionId'] as int,
          QueuedSubmission.fromMap(
            Map<String, Object?>.from(map['submission'] as Map),
          ),
        ).catchError((Object error) {
          debugPrint('[IvyPulse] Queue prompt failed: $error');
          toWorker?.send(mainPromptDeferred(map['submissionId'] as int));
        }));
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
            debugPrint('[IvyPulse] Queued send failed: $error');
            return false;
          }
        }, queuedOnFailure: true, withdrawal: submission.isWithdrawal);

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
    final alreadySent = delivery.status(
            submission.entityId, submission.transport,
            withdrawal: submission.isWithdrawal) ==
        DeliveryStatus.sent;
    final send = submission.isWithdrawal ||
            alreadySent ||
            await delivery.isWithdrawn(submission.entityId)
        ? true
        : await promptStrategy.ask(submission);
    if (send == null) {
      toWorker?.send(mainPromptDeferred(submissionId));
      return;
    }
    if (!send) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.discarded);
    }
    toWorker?.send(
      mainPromptResponse(submissionId: submissionId, send: send),
    );
  }

  Future<void> handleDelete(int submissionId) async {
    try {
      await repository.deleteById(submissionId);
      delivery.queueChanged();
    } catch (error) {
      debugPrint(
        '[IvyPulse] QueueWorker: delete failed for $submissionId: $error',
      );
    }
  }
}
