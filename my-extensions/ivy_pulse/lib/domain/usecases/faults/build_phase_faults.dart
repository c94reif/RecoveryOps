import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';

/// Turns a phase's non-serviceable answers into faults, pulling the category,
/// component, and TM instruction off the catalog so the fault stands alone on
/// the 5988-E.
///
/// Pure and synchronous — safe to run on a background isolate for a long
/// walk-around, and trivially testable.
class BuildPhaseFaults {
  const BuildPhaseFaults();

  List<PmcsFault> call({
    required String sessionId,
    required PmcsPhase phase,
    required PmcsCatalog catalog,
    required Map<String, CheckResult> results,
  }) {
    final faults = <PmcsFault>[];

    for (final category in catalog.categoriesFor(phase)) {
      for (final item in category.items) {
        final result = results[item.id];
        if (result == null || result.isServiceable) continue;

        faults.add(
          PmcsFault(
            sessionId: sessionId,
            itemId: item.id,
            phase: phase,
            category: category.name,
            subcategory: item.item,
            description: item.check,
            condition: result.faultLabel,
            severity: result.severity ?? FaultSeverity.dash,
            note: result.note,
            recordedAt: result.recordedAt,
          ),
        );
      }
    }

    return faults;
  }
}
