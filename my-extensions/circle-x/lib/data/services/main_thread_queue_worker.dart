import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/queue_prompt_strategy.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';

class MainThreadQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueuePromptStrategy promptStrategy;
  final UserNotificationSink snackBarService;
  final Duration probeInterval;
  final DeliveryCoordinator delivery;

  final Map<String, List<QueuedSubmission>> pending = {
    'lattice': [],
    'mesh': [],
  };
  final Map<String, bool> connected = {
    'lattice': true,
    'mesh': true,
  };
  final Map<String, bool> draining = {
    'lattice': false,
    'mesh': false,
  };

  Timer? probeTimer;
  Future<void>? starting;

  MainThreadQueueWorker({
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
    if (probeTimer != null) return;

    final resumed = await repository.getAll();
    for (final submission in resumed) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.queued,
          withdrawal: submission.isWithdrawal);
      if (submission.isWithdrawal) delivery.suppressReport(submission.entityId);
    }
    for (final submission in resumed) {
      final transportQueue = pending[submission.transport.wireName]!;
      if (!transportQueue
          .any((pendingSubmission) => pendingSubmission.id == submission.id)) {
        transportQueue.add(submission);
      }
    }
    debugPrint('[CircleX] QueueWorker: resumed ${resumed.length} pending');

    probeTimer = Timer.periodic(probeInterval, (_) => onProbeTick());
  }

  @override
  Future<void> stop() async {
    probeTimer?.cancel();
    probeTimer = null;
    for (final parked in pending.values) {
      parked.clear();
    }
    for (final key in pending.keys) {
      connected[key] = true;
      draining[key] = false;
    }
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
    final key = submission.transport.wireName;
    if (!pending[key]!
        .any((pendingSubmission) => pendingSubmission.id == submission.id)) {
      pending[key]!.add(submission);
    }
    if (submission.isWithdrawal) delivery.suppressReport(submission.entityId);
    connected[key] = false;
    delivery.queueChanged();
  }

  @override
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  }) {
    final key = transport.wireName;
    if (!success) {
      connected[key] = false;
      return;
    }
    connected[key] = true;
    unawaited(drainNext(transport).catchError((Object error) {
      debugPrint('[CircleX] Queue drain failed: $error');
    }));
  }

  @override
  Future<int> pendingCount() => repository.count();

  Future<void> onProbeTick() async {
    await Future.wait(TransportKind.values
        .map((transport) => nudge(transport).catchError((Object error) {
              debugPrint('[CircleX] Queue probe failed: $error');
            })));
  }

  Future<void> nudge(TransportKind transport) async {
    final key = transport.wireName;
    if (draining[key] == true) return;
    if (pending[key]!.isEmpty) return;
    if (connected[key] == true) {
      await drainNext(transport);
      return;
    }
    await probe(transport);
  }

  Future<void> probe(TransportKind transport) async {
    final key = transport.wireName;
    final oldest = pending[key]!.first;

    draining[key] = true;
    try {
      final success = await attemptSend(oldest);
      if (!success) return;
      connected[key] = true;
      await settle(oldest);
      snackBarService.enqueue('${transport.displayName}: sent (queued)');
    } finally {
      draining[key] = false;
    }
    await drainNext(transport);
  }

  Future<void> drainNext(TransportKind transport) async {
    final key = transport.wireName;
    if (draining[key] == true) return;
    if (connected[key] != true) return;
    final parked = pending[key]!;
    if (parked.isEmpty) return;

    final next = parked.first;
    draining[key] = true;
    try {
      final alreadySent = delivery.status(next.entityId, next.transport,
              withdrawal: next.isWithdrawal) ==
          DeliveryStatus.sent;
      final shouldSend = next.isWithdrawal ||
              alreadySent ||
              await delivery.isWithdrawn(next.entityId)
          ? true
          : await promptStrategy.ask(next);
      if (shouldSend == null) {
        return;
      }
      if (!shouldSend) {
        delivery.update(
            next.entityId, next.transport, DeliveryStatus.discarded);
        await settle(next);
      } else {
        final success = await attemptSend(next);
        snackBarService.enqueue(
          '${transport.displayName}: '
          '${success ? 'sent (queued)' : 'still FAILED'}',
          isError: !success,
        );
        if (!success) {
          connected[key] = false;
          return;
        }
        connected[key] = true;
        await settle(next);
      }
    } finally {
      draining[key] = false;
    }

    await drainNext(transport);
  }

  Future<bool> attemptSend(QueuedSubmission submission) async {
    if (delivery.status(submission.entityId, submission.transport,
            withdrawal: submission.isWithdrawal) ==
        DeliveryStatus.sent) {
      return true;
    }
    return delivery.send(submission.entityId, submission.transport, () async {
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
  }

  Future<void> settle(QueuedSubmission submission) async {
    final id = submission.id;
    pending[submission.transport.wireName]!
        .removeWhere((pendingSubmission) => pendingSubmission.id == id);
    if (id == null) return;
    try {
      await repository.deleteById(id);
      delivery.queueChanged();
    } catch (error) {
      debugPrint('[CircleX] QueueWorker: delete failed for $id: $error');
    }
  }
}
