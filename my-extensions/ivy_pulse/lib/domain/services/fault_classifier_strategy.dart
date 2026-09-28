import 'package:ivy_pulse/domain/entities/fault_severity.dart';

abstract class FaultClassifierStrategy {
  FaultSeverity? classify({
    required String itemId,
    required int faultIndex,
  });

  bool isCriticalSystem(String itemId);
}
