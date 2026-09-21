import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

/// Pulls PMCS reports other crews published to Lattice and stores the ones
/// this device has not seen. Mesh delivery is best-effort, so this is how a
/// maintainer who was out of radio range still gets the fault list.
class SyncRemoteReports {
  final RemoteReportSource source;
  final ReportsRepository repository;

  const SyncRemoteReports(this.source, this.repository);

  Future<List<PmcsReport>> call(List<PmcsReport> currentReports) async {
    try {
      final remote = await source.fetchRemotePmcsReports();
      if (remote.isEmpty) return const [];

      final knownIds = <String>{
        for (final report in currentReports)
          if (report.entityId.isNotEmpty) report.entityId,
      };

      final fresh = <PmcsReport>[];
      for (final report in remote) {
        if (report.entityId.isEmpty) continue;
        if (knownIds.contains(report.entityId)) continue;

        final stored = await repository.insertReport(report);
        knownIds.add(report.entityId);
        fresh.add(stored);
      }
      return fresh;
    } catch (e) {
      debugPrint('[IvyPulse] SyncRemoteReports error: $e');
      return const [];
    }
  }
}
