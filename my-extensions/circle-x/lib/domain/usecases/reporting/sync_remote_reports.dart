import 'package:circle_x/domain/services/diagnostic_logger.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/services/remote_report_source.dart';
import 'package:circle_x/domain/usecases/reporting/store_received_report.dart';

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
          for (final stored in await storeReceivedReport(repository, report)) {
            if (knownIds.add(stored.entityId)) fresh.add(stored);
          }
        } on ReportWithdrawn {
          continue;
        }
      }
      return fresh;
    } catch (error) {
      logger.log('[CircleX] SyncRemoteReports error: $error');
      return const [];
    }
  }
}
