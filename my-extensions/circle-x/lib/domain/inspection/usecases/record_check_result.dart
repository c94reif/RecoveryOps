import 'package:circle_x/domain/inspection/entities/check_result.dart';
import 'package:circle_x/domain/inspection/entities/fault_description.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_check_item.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_phase.dart';
import 'package:circle_x/domain/inspection/repositories/results_repo.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/inspection/services/fault_classifier_strategy.dart';

class RecordCheckResult {
  final ResultsRepository repository;
  final FaultClassifierStrategy classifier;
  final Clock clock;

  const RecordCheckResult({
    required this.repository,
    required this.classifier,
    required this.clock,
  });

  Future<CheckResult> call({
    required String sessionId,
    required PmcsPhase phase,
    required PmcsCheckItem item,
    required int faultIndex,
    String? note,
  }) async {
    final result = CheckResult(
      itemId: item.id,
      faultIndex: faultIndex,
      faultLabel: item.labelAt(faultIndex),
      severity: classifier.classify(itemId: item.id, faultIndex: faultIndex),
      note: faultIndex == 0 ? null : normalizeFaultDescription(note),
      recordedAt: clock.nowUtc(),
    );

    await repository.upsertResult(sessionId, phase, result);
    return result;
  }
}
