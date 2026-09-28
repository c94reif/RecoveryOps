import 'package:ivy_pulse/domain/services/diagnostic_logger.dart';

import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

class SyncLocalReportsToLattice {
  final DiagnosticLogger logger;
  final RemoteReportSource source;
  final PmcsEntityPort entityPort;

  final DeliveryCoordinator delivery;
  final QueuedSubmissionsRepository? queuedRepository;

  SyncLocalReportsToLattice(
    this.source,
    this.entityPort, {
    this.logger = const SilentDiagnosticLogger(),
    DeliveryCoordinator? delivery,
    this.queuedRepository,
  }) : delivery = delivery ?? DeliveryCoordinator();

  Future<int> call(List<PmcsReport> reports) async {
    final revision = delivery.revision;
    try {
      final outgoing = reports
          .where((report) => report.isOutgoing && report.entityId.isNotEmpty)
          .toList();
      if (outgoing.isEmpty) return 0;

      final knownIds = await source.fetchKnownPmcsEntityIds();

      final parked = await queuedRepository?.getAll() ?? const [];
      final queuedIds = parked
          .where((submission) => submission.transport == TransportKind.lattice)
          .map((submission) => submission.entityId)
          .toSet();
      var republished = 0;
      for (final report in outgoing) {
        if (await delivery.isWithdrawn(report.entityId)) continue;
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
        final sentSuccessfully = await delivery.send(report.entityId,
            TransportKind.lattice, () => entityPort.publishPmcsReport(report));
        if (sentSuccessfully) republished++;
      }
      if (republished > 0) {
        logger.log('[IvyPulse] Re-published $republished local report(s)');
      }
      return republished;
    } catch (error) {
      logger.log('[IvyPulse] SyncLocalReportsToLattice error: $error');
      return 0;
    }
  }
}
