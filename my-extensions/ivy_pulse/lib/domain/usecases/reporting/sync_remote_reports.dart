import 'package:ivy_pulse/domain/services/diagnostic_logger.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/services/remote_report_source.dart';

class SyncRemoteReports {
  final DiagnosticLogger logger;
  final RemoteReportSource source;
  final ReportsRepository repository;

  const SyncRemoteReports(this.source, this.repository,
      {this.logger = const SilentDiagnosticLogger()});

  Future<List<PmcsReport>> call(List<PmcsReport> currentReports) async {
    try {
      for (final id in await source.fetchWithdrawnPmcsEntityIds()) {
        await repository.withdrawReport(id);
      }
      final remote = await source.fetchRemotePmcsReports();
      if (remote.isEmpty) return const [];

      final withdrawn = await repository.getWithdrawnIds();

      final knownIds = <String>{
        for (final report in currentReports)
          if (report.entityId.isNotEmpty) report.entityId,
      };

      final fresh = <PmcsReport>[];
      for (final report in remote) {
        if (report.entityId.isEmpty) continue;
        if (withdrawn.contains(report.entityId)) continue;
        if (knownIds.contains(report.entityId)) continue;

        try {
          final stored = await repository.insertReport(report);
          knownIds.add(report.entityId);
          fresh.add(stored);
        } on ReportWithdrawn {
          continue;
        }
      }
      return fresh;
    } catch (error) {
      logger.log('[IvyPulse] SyncRemoteReports error: $error');
      return const [];
    }
  }
}
