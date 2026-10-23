import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/domain/delivery/entities/queued_submission.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';
import 'package:circle_x/domain/delivery/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:circle_x/domain/delivery/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/delivery/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/delivery/services/queue_prompt_strategy.dart';
import 'package:circle_x/domain/delivery/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/shared/services/user_notification_sink.dart';

class MainThreadQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
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
  final _drains = <String, Future<void>>{};
  final _failures = <String, int>{};
  final _skipProbes = <String, int>{};
  int _generation = 0;

  MainThreadQueueWorker({
    required this.repository,
    required this.entityPort,
    required this.meshPort,
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
    if (probeTimer != null) return;

    final generation = _generation;
    final resumed = await repository.getAll();
    if (generation != _generation) return;
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
    unawaited(onProbeTick());
  }

  @override
  Future<void> stop() async {
    _generation++;
    starting = null;
    _drains.clear();
    _failures.clear();
    _skipProbes.clear();
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
    _failures.remove(key);
    _skipProbes.remove(key);
    unawaited(drainNext(transport).catchError((Object error) {
      debugPrint('[CircleX] Queue drain failed: $error');
    }));
  }

  @override
  Future<int> pendingCount() => repository.count();

  @override
  Future<void> retryNow() async {
    _failures.clear();
    _skipProbes.clear();
    await onProbeTick();
  }

  @override
  Future<bool> sendNow(QueuedSubmission submission) async {
    if (probeTimer == null) return false;
    final key = submission.transport.wireName;
    final row = pending[key]!
        .where((pendingSubmission) => pendingSubmission.id == submission.id)
        .firstOrNull;
    if (row == null) return true;
    final generation = _generation;
    try {
      final success = await attemptSend(row);
      if (generation != _generation) return false;
      if (!success) {
        _backOff(key);
        return false;
      }
      if (!await settle(row, generation: generation)) {
        if (generation == _generation) _backOff(key);
        return true;
      }
      connected[key] = true;
      _failures.remove(key);
      _skipProbes.remove(key);
      unawaited(drainNext(submission.transport).catchError((Object error) {
        debugPrint('[CircleX] Queue drain failed: $error');
      }));
      return true;
    } catch (error) {
      if (generation == _generation) _backOff(key);
      debugPrint('[CircleX] Queued send failed: $error');
      return false;
    }
  }

  Future<void> onProbeTick() async {
    await Future.wait(TransportKind.values.map((transport) async {
      final key = transport.wireName;
      final skipped = _skipProbes[key] ?? 0;
      if (skipped > 0) {
        _skipProbes[key] = skipped - 1;
        return;
      }
      await nudge(transport);
    }));
  }

  Future<void> nudge(TransportKind transport) => drainNext(transport);

  Future<void> probe(TransportKind transport) => drainNext(transport);

  Future<void> drainNext(TransportKind transport) {
    final key = transport.wireName;
    final active = _drains[key];
    if (active != null) return active;
    final generation = _generation;
    final drain = _drain(transport, generation).whenComplete(() {
      if (generation == _generation) _drains.remove(key);
    });
    _drains[key] = drain;
    return drain;
  }

  Future<void> _drain(TransportKind transport, int generation) async {
    final key = transport.wireName;
    draining[key] = true;
    try {
      while (generation == _generation && pending[key]!.isNotEmpty) {
        final next = pending[key]!.first;
        final success = await attemptSend(next);
        if (generation != _generation) return;
        if (!success) {
          _backOff(key);
          return;
        }
        final settled = await settle(next, generation: generation);
        if (generation != _generation) return;
        if (!settled) {
          _backOff(key);
          return;
        }
        connected[key] = true;
        _failures.remove(key);
        _skipProbes.remove(key);
      }
    } catch (error) {
      if (generation == _generation) _backOff(key);
      debugPrint('[CircleX] Queue drain failed: $error');
    } finally {
      if (generation == _generation) draining[key] = false;
    }
  }

  void _backOff(String key) {
    connected[key] = false;
    final failures = ((_failures[key] ?? 0) + 1).clamp(1, 5);
    _failures[key] = failures;
    _skipProbes[key] = (1 << (failures - 1)) - 1;
  }

  Future<bool> attemptSend(QueuedSubmission submission) async {
    final source = submission.reviewSourceReportId;
    if (!submission.isWithdrawal &&
        source != null &&
        await delivery.isWithdrawn(source)) {
      delivery.update(
          submission.entityId, submission.transport, DeliveryStatus.discarded);
      return true;
    }
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

  Future<bool> settle(QueuedSubmission submission, {int? generation}) async {
    final id = submission.id;
    try {
      if (id != null) await repository.deleteById(id);
      if (generation != null && generation != _generation) return false;
      pending[submission.transport.wireName]!
          .removeWhere((row) => row.id == id);
      delivery.queueChanged();
      return true;
    } catch (error) {
      debugPrint('[CircleX] QueueWorker: delete failed for $id: $error');
      return false;
    }
  }
}
