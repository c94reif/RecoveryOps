import 'package:flutter/foundation.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';

class SyncRemoteReports {
  final RemoteReportSource source;
  final ReportsRepository repository;

  SyncRemoteReports(this.source, this.repository);

  Future<List<RecoveryReport>> call(List<RecoveryReport> currentReports) async {
    try {
      final remote = await source.fetchRemoteRecoveryReports();
      if (remote.isEmpty) return const [];

      final knownIds = <String>{
        for (final r in currentReports)
          if (r.entityId != null && r.entityId!.isNotEmpty) r.entityId!,
      };

      final newReports = <RecoveryReport>[];
      for (final report in remote) {
        final id = report.entityId;
        if (id == null || id.isEmpty) continue;
        if (knownIds.contains(id)) continue;

        await repository.insertReport(report);
        knownIds.add(id);
        newReports.add(report);
      }
      return newReports;
    } catch (e) {
      debugPrint('[RecoveryOps] SyncRemoteReports error: $e');
      return const [];
    }
  }
}
