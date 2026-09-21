import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';

abstract class ResultsRepository {
  /// Answers already recorded for a phase, keyed by TM item id.
  Future<Map<String, CheckResult>> getResults(
    String sessionId,
    PmcsPhase phase,
  );

  /// Records an answer, replacing any previous answer for the same item.
  Future<void> upsertResult(
    String sessionId,
    PmcsPhase phase,
    CheckResult result,
  );

  Future<void> deleteForSession(String sessionId);
}
