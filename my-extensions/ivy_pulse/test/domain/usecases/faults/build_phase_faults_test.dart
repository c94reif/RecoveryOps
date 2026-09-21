import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/usecases/faults/build_phase_faults.dart';

const catalog = PmcsCatalog(
  vehicleType: VehicleType.stryker,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(
        name: 'ENGINE COMPARTMENT',
        items: [
          PmcsCheckItem(
            id: 'B-ENG-01',
            item: 'Engine Oil Level',
            check: 'Check dipstick',
            faults: ['Level OK', 'Low', 'Overfull', 'Contaminated'],
          ),
          PmcsCheckItem(
            id: 'B-ENG-02',
            item: 'Coolant Level',
            check: 'Check coolant',
            faults: ['Level OK', 'Low', 'Discolored', 'Cap Missing'],
          ),
        ],
      ),
      PmcsCategory(
        name: 'BRAKES',
        items: [
          PmcsCheckItem(
            id: 'B-BRK-01',
            item: 'Brake Fluid',
            check: 'Reservoir between MIN and MAX',
            faults: ['Level OK', 'Low', 'Empty', 'Reservoir Cracked'],
          ),
        ],
      ),
    ],
    PmcsPhase.during: [],
    PmcsPhase.after: [],
  },
);

CheckResult result(
  String itemId,
  int faultIndex,
  String label, {
  FaultSeverity? severity,
  String? note,
}) {
  return CheckResult(
    itemId: itemId,
    faultIndex: faultIndex,
    faultLabel: label,
    severity: severity,
    note: note,
    recordedAt: DateTime.utc(2026, 3, 24, 7),
  );
}

void main() {
  const usecase = BuildPhaseFaults();

  test('returns no faults when everything is serviceable', () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-ENG-01': result('B-ENG-01', 0, 'Level OK'),
        'B-ENG-02': result('B-ENG-02', 0, 'Level OK'),
      },
    );

    expect(faults, isEmpty);
  });

  test('raises a fault for each non-serviceable answer', () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-ENG-01': result('B-ENG-01', 0, 'Level OK'),
        'B-ENG-02': result('B-ENG-02', 1, 'Low', severity: FaultSeverity.dash),
        'B-BRK-01': result('B-BRK-01', 3, 'Reservoir Cracked',
            severity: FaultSeverity.redX),
      },
    );

    expect(faults.map((f) => f.itemId), ['B-ENG-02', 'B-BRK-01']);
  });

  test('copies category, component, and TM instruction off the catalog', () {
    final faults = usecase(
      sessionId: 'session-9',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-BRK-01': result('B-BRK-01', 2, 'Empty',
            severity: FaultSeverity.redX, note: 'pedal to the floor'),
      },
    );

    final fault = faults.single;
    expect(fault.sessionId, 'session-9');
    expect(fault.category, 'BRAKES');
    expect(fault.subcategory, 'Brake Fluid');
    expect(fault.description, 'Reservoir between MIN and MAX');
    expect(fault.condition, 'Empty');
    expect(fault.severity, FaultSeverity.redX);
    expect(fault.phase, PmcsPhase.before);
    expect(fault.note, 'pedal to the floor');
    expect(fault.recordedAt, DateTime.utc(2026, 3, 24, 7));
  });

  test('preserves TM walk-around order, not answer order', () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-BRK-01': result('B-BRK-01', 1, 'Low', severity: FaultSeverity.dash),
        'B-ENG-01': result('B-ENG-01', 1, 'Low', severity: FaultSeverity.dash),
      },
    );

    expect(faults.map((f) => f.itemId), ['B-ENG-01', 'B-BRK-01']);
  });

  test('defaults a missing severity to DASH rather than dropping the fault',
      () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {'B-ENG-01': result('B-ENG-01', 1, 'Low')},
    );

    expect(faults.single.severity, FaultSeverity.dash);
  });

  test('ignores answers for items outside the phase', () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.during,
      catalog: catalog,
      results: {
        'B-ENG-01': result('B-ENG-01', 1, 'Low', severity: FaultSeverity.dash),
      },
    );

    expect(faults, isEmpty);
  });

  test('correctionRequired follows severity', () {
    final faults = usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-ENG-01': result('B-ENG-01', 1, 'Low', severity: FaultSeverity.dash),
        'B-ENG-02': result('B-ENG-02', 3, 'Cap Missing',
            severity: FaultSeverity.circleX),
      },
    );

    expect(faults[0].correctionRequired, isFalse);
    expect(faults[1].correctionRequired, isTrue);
  });
}
