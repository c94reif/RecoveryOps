import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/services/fault_classifier_strategy.dart';

class TmFaultClassifier implements FaultClassifierStrategy {
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
