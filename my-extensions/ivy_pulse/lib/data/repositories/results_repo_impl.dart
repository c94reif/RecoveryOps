import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';

class ResultsRepoImpl implements ResultsRepository {
  final CheckResultsDao dao;

  ResultsRepoImpl(this.dao);

  @override
  Future<Map<String, CheckResult>> getResults(
    String sessionId,
    PmcsPhase phase,
  ) async {
    final rows = await dao.getResults(sessionId, phase.wireName);
    return {
      for (final row in rows)
        row.itemId: CheckResult(
          itemId: row.itemId,
          faultIndex: row.faultIndex,
          faultLabel: row.faultLabel,
          severity: FaultSeverity.tryFromWireName(row.severity),
          note: row.note,
          recordedAt: row.recordedAt,
        ),
    };
  }

  @override
  Future<void> upsertResult(
    String sessionId,
    PmcsPhase phase,
    CheckResult result,
  ) async {
    await dao.upsertResult(
      sessionId: sessionId,
      phase: phase.wireName,
      itemId: result.itemId,
      faultIndex: result.faultIndex,
      faultLabel: result.faultLabel,
      severity: result.severity?.wireName,
      note: result.note,
      recordedAt: result.recordedAt,
    );
  }

  @override
  Future<void> deleteForSession(String sessionId) =>
      dao.deleteForSession(sessionId);
}
