import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';

/// Grades an answer the way the TM's fault tables do.
///
/// Severity is a function of two things only: whether the item belongs to a
/// system the TM deadlines the vehicle over, and how far down the condition
/// list the operator went — the catalogs are transcribed serviceable-first
/// with conditions escalating by index.
class TmFaultClassifier implements FaultClassifierStrategy {
  /// Item id fragments that mark a "Not Mission Capable If" system.
  ///
  /// `CRIT` is the marker the JLTV transcription carries (`JLTV-CRIT-*`); the
  /// rest are the Stryker item numbers for engine, brakes, drivetrain, fuel
  /// and the weapon station — the systems a commander cannot dispatch a
  /// vehicle on, so a serious fault there is a RED X rather than a work order.
  static const List<String> criticalSystemMarkers = [
    'CRIT',
    'ENG-01',
    'ENG-02',
    'BRK-01',
    'DRV-01',
    'DRV-02',
    'FUL-03',
    'WPN-01',
  ];

  const TmFaultClassifier();

  @override
  FaultSeverity? classify({required String itemId, required int faultIndex}) {
    if (faultIndex == 0) return null;

    final critical = isCriticalSystem(itemId);
    if (critical && faultIndex >= 3) return FaultSeverity.redX;
    if (critical && faultIndex >= 1) return FaultSeverity.circleX;
    if (faultIndex >= 3) return FaultSeverity.circleX;
    return FaultSeverity.dash;
  }

  @override
  bool isCriticalSystem(String itemId) =>
      criticalSystemMarkers.any(itemId.contains);
}
