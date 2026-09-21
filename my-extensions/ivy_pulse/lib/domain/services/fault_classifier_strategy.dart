import 'package:ivy_pulse/domain/entities/fault_severity.dart';

/// Grades an operator's selection against the TM's fault tiers.
///
/// Returns null when the selection is the serviceable option — no fault.
abstract class FaultClassifierStrategy {
  FaultSeverity? classify({
    required String itemId,
    required int faultIndex,
  });

  /// Whether the TM flags this item with a "Not Mission Capable If" condition.
  bool isCriticalSystem(String itemId);
}
