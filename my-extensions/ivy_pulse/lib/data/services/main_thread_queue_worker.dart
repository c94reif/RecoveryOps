import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';

/// The queue worker for the web build.
///
/// `Isolate.spawn` throws on Flutter web, and this extension ships as a web
/// build running inside the host's Android WebView, so there is no worker
/// isolate to hand the state machine to — a periodic [Timer] drives it on the
/// main thread instead.
///
/// The rules are the ones in `queue_worker_entrypoint.dart`, held in step by
/// hand rather than shared, because there they are message handlers on a
/// `SendPort` and here they are awaited calls: park per transport, ask the
/// operator about the oldest parked submission when a leg comes back, and keep
/// draining that leg only while it holds up. Change one, change the other.
class MainThreadQueueWorker implements QueueWorkerStrategy {
  final QueuedSubmissionsRepository repository;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueuePromptStrategy promptStrategy;
  final SnackBarService snackBarService;
  final Duration probeInterval;

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

  MainThreadQueueWorker({
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
    if (probeTimer != null) return;

    final resumed = await repository.getAll();
    for (final submission in resumed) {
      pending[submission.transport.wireName]!.add(submission);
    }
    debugPrint('[IvyPulse] QueueWorker: resumed ${resumed.length} pending');

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
    final key = stored.transport.wireName;
    pending[key]!.add(stored);
    connected[key] = false;
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
    final key = transport.wireName;
    if (!success) {
      connected[key] = false;
      return;
    }
    connected[key] = true;
    // A live submission just landed on this leg, which is the strongest proof
    // it is back — start emptying the backlog without waiting for a probe.
    unawaited(drainNext(transport));
  }

  @override
  Future<int> pendingCount() => repository.count();

  Future<void> onProbeTick() async {
    for (final transport in TransportKind.values) {
      await nudge(transport);
    }
  }

  Future<void> nudge(TransportKind transport) async {
    final key = transport.wireName;
    if (draining[key] == true) return;
    if (pending[key]!.isEmpty) return;
    if (connected[key] == true) {
      // Reachable after a resume from disk, where the queue starts out
      // assuming both legs are up: go straight to asking the operator.
      await drainNext(transport);
      return;
    }
    await probe(transport);
  }

  /// Tests a down leg with real traffic — the oldest parked submission.
  ///
  /// Neither transport offers a cheaper reachability check, and if it lands the
  /// PMCS is actually delivered instead of merely proven deliverable. The
  /// operator is not prompted first: they already chose to send this one, and
  /// they are not asked again on failure because the probe repeats every
  /// [probeInterval] and nagging a crew mid-maintenance is worse than silence.
  Future<void> probe(TransportKind transport) async {
    final key = transport.wireName;
    final oldest = pending[key]!.first;

    draining[key] = true;
    final success = await attemptSend(oldest);
    draining[key] = false;

    if (!success) return;

    connected[key] = true;
    await settle(oldest);
    snackBarService.enqueue('${transport.displayName}: sent (queued)');
    await drainNext(transport);
  }

  /// Offer the oldest parked submission on this leg, then keep going only
  /// while the leg holds up — the parallel of `requestNextPrompt` /
  /// `onPromptResponse` / `onExecuteResult` in the isolate entrypoint.
  Future<void> drainNext(TransportKind transport) async {
    final key = transport.wireName;
    if (draining[key] == true) return;
    if (connected[key] != true) return;
    final parked = pending[key]!;
    if (parked.isEmpty) return;

    final next = parked.first;
    draining[key] = true;
    try {
      final shouldSend = await promptStrategy.ask(next);
      if (shouldSend == null) {
        // Nobody was on screen to ask. Leave it parked and try again on the
        // next probe — discarding a PMCS nobody was asked about would lose an
        // operator's whole walk-around.
        return;
      }
      if (!shouldSend) {
        await settle(next);
      } else {
        final success = await attemptSend(next);
        snackBarService.enqueue(
          '${transport.displayName}: '
          '${success ? 'sent (queued)' : 'still FAILED'}',
          isError: !success,
        );
        if (!success) {
          // The leg dropped again between the prompt and the send; leave the
          // rest parked rather than walking the operator through failures.
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
    final position = LatLng(submission.latitude, submission.longitude);
    switch (submission.transport) {
      case TransportKind.lattice:
        // The stored payload is re-sent verbatim: the session it came from may
        // have been continued or abandoned since it was parked.
        return entityPort.publishEncodedReport(
          entityId: submission.entityId,
          payload: submission.payload,
          position: position,
        );
      case TransportKind.mesh:
        return meshPort.broadcastEncodedReport(submission.payload);
    }
  }

  /// Drop a submission for good — it either landed or the operator discarded
  /// it. The row goes with it so a restart does not resurrect it.
  Future<void> settle(QueuedSubmission submission) async {
    final id = submission.id;
    pending[submission.transport.wireName]!.removeWhere((s) => s.id == id);
    if (id == null) return;
    try {
      await repository.deleteById(id);
    } catch (e) {
      debugPrint('[IvyPulse] QueueWorker: delete failed for $id: $e');
    }
  }
}
