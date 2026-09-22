import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_description.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';

/// Grades and stores one answer. Writing through on every tap is what lets an
/// operator lose the vehicle's power, close the app, or hand the EUD off
/// mid-walk-around without losing the checks already done.
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
