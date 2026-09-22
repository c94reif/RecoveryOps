import 'package:flutter/foundation.dart';

import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

/// Re-publishes this device's own reports that are missing from the host —
/// the repair path for a submission that went out while Lattice was down and
/// was never picked up off the queue.
class SyncLocalReportsToLattice {
  final RemoteReportSource source;
  final PmcsEntityPort entityPort;

  final DeliveryCoordinator delivery;
  final QueuedSubmissionsRepository? queuedRepository;

  SyncLocalReportsToLattice(
    this.source,
    this.entityPort, {
    DeliveryCoordinator? delivery,
    this.queuedRepository,
  }) : delivery = delivery ?? DeliveryCoordinator();

  Future<int> call(List<PmcsReport> reports) async {
    final revision = delivery.revision;
    try {
      final outgoing =
          reports.where((r) => r.isOutgoing && r.entityId.isNotEmpty).toList();
      if (outgoing.isEmpty) return 0;

      final knownIds = await source.fetchKnownPmcsEntityIds();

      final parked = await queuedRepository?.getAll() ?? const [];
      final queuedIds = parked
          .where((s) => s.transport == TransportKind.lattice)
          .map((s) => s.entityId)
          .toSet();
      var republished = 0;
      for (final report in outgoing) {
        if (knownIds.contains(report.entityId) ||
            queuedIds.contains(report.entityId) ||
            delivery.status(report.entityId, TransportKind.lattice) ==
                DeliveryStatus.queued ||
            delivery.status(report.entityId, TransportKind.lattice) ==
                DeliveryStatus.discarded ||
            delivery.busyOrAttemptedSince(
                report.entityId, TransportKind.lattice, revision)) {
          continue;
        }
        final ok = await delivery.send(report.entityId, TransportKind.lattice,
            () => entityPort.publishPmcsReport(report));
        if (ok) republished++;
      }
      if (republished > 0) {
        debugPrint('[IvyPulse] Re-published $republished local report(s)');
      }
      return republished;
    } catch (e) {
      debugPrint('[IvyPulse] SyncLocalReportsToLattice error: $e');
      return 0;
    }
  }
}
