import 'package:circle_x/domain/inspection/entities/check_result.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_phase.dart';

abstract class ResultsRepository {
  Future<Map<String, CheckResult>> getResults(
    String sessionId,
    PmcsPhase phase,
  );

  Future<void> upsertResult(
    String sessionId,
    PmcsPhase phase,
    CheckResult result,
  );

  Future<void> deleteForSession(String sessionId);
}
