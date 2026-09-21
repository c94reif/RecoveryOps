import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

/// Re-publishes this device's own reports that are missing from the host —
/// the repair path for a submission that went out while Lattice was down and
/// was never picked up off the queue.
class SyncLocalReportsToLattice {
  final RemoteReportSource source;
  final PmcsEntityPort entityPort;

  const SyncLocalReportsToLattice(this.source, this.entityPort);

  Future<int> call(List<PmcsReport> reports) async {
    try {
      final outgoing =
          reports.where((r) => r.isOutgoing && r.entityId.isNotEmpty).toList();
      if (outgoing.isEmpty) return 0;

      final knownIds = await source.fetchKnownPmcsEntityIds();

      var republished = 0;
      for (final report in outgoing) {
        if (knownIds.contains(report.entityId)) continue;
        final ok = await entityPort.publishPmcsReport(report);
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
