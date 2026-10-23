import 'package:circle_x/domain/catalog/entities/fault_severity.dart';

abstract class FaultClassifierStrategy {
  FaultSeverity? classify({
    required String itemId,
    required int faultIndex,
  });

  bool isCriticalSystem(String itemId);
}
