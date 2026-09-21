import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/usecases/session/complete_phase.dart';

import '../../../support/fakes.dart';

const catalog = PmcsCatalog(
  vehicleType: VehicleType.stryker,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(
        name: 'BRAKES',
        items: [
          PmcsCheckItem(
            id: 'B-BRK-01',
            item: 'Brake Fluid',
            check: 'Reservoir between MIN and MAX',
            faults: ['Level OK', 'Low', 'Empty', 'Cracked'],
          ),
          PmcsCheckItem(
            id: 'B-BRK-02',
            item: 'Parking Brake',
            check: 'Engages and holds',
            faults: ['Holds Firm', 'Slips', 'Wont Engage', 'Cable Frayed'],
          ),
        ],
      ),
    ],
    PmcsPhase.during: [],
    PmcsPhase.after: [],
  },
);

CheckResult answer(String itemId, int index, String label,
        {FaultSeverity? severity}) =>
    CheckResult(
      itemId: itemId,
      faultIndex: index,
      faultLabel: label,
      severity: severity,
      recordedAt: DateTime.utc(2026, 3, 24, 7),
    );

void main() {
  late FakeSessionsRepository sessions;
  late FakeFaultsRepository faults;
  late CompletePhase usecase;

  setUp(() {
    sessions = FakeSessionsRepository();
    faults = FakeFaultsRepository();
    usecase = CompletePhase(
      sessionsRepository: sessions,
      faultsRepository: faults,
    );
  });

  test('marks the phase complete on the session', () async {
    final outcome = await usecase(
      session: buildSession(),
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {'B-BRK-01': answer('B-BRK-01', 0, 'Level OK')},
    );

    expect(outcome.session.isPhaseComplete(PmcsPhase.before), isTrue);
    expect(sessions.updated, hasLength(1));
  });

  test('stores the faults derived from the phase', () async {
    final outcome = await usecase(
      session: buildSession(),
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-BRK-01':
            answer('B-BRK-01', 2, 'Empty', severity: FaultSeverity.redX),
        'B-BRK-02': answer('B-BRK-02', 0, 'Holds Firm'),
      },
    );

    expect(outcome.faults, hasLength(1));
    expect(outcome.faults.single.itemId, 'B-BRK-01');
    expect(await faults.getForSession('session-1'), hasLength(1));
  });

  test('re-completing a phase replaces its faults instead of duplicating',
      () async {
    final session = buildSession();

    await usecase(
      session: session,
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-BRK-01':
            answer('B-BRK-01', 2, 'Empty', severity: FaultSeverity.redX),
      },
    );
    await usecase(
      session: session,
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {'B-BRK-01': answer('B-BRK-01', 0, 'Level OK')},
    );

    expect(await faults.getForSession('session-1'), isEmpty);
  });

  test('faults from other phases survive completing this one', () async {
    await faults.replacePhaseFaults(
      'session-1',
      [buildFault(itemId: 'A-CDN-01', phase: PmcsPhase.after)],
      phaseWireName: PmcsPhase.after.wireName,
    );

    await usecase(
      session: buildSession(),
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {'B-BRK-01': answer('B-BRK-01', 0, 'Level OK')},
    );

    expect(await faults.getForSession('session-1'), hasLength(1));
  });

  test('reports the tally for the phase', () async {
    final outcome = await usecase(
      session: buildSession(),
      phase: PmcsPhase.before,
      catalog: catalog,
      results: {
        'B-BRK-01':
            answer('B-BRK-01', 2, 'Empty', severity: FaultSeverity.redX),
        'B-BRK-02':
            answer('B-BRK-02', 1, 'Slips', severity: FaultSeverity.dash),
      },
    );

    expect(outcome.tally.redX, 1);
    expect(outcome.tally.dash, 1);
    expect(outcome.tally.isDeadlined, isTrue);
  });

  test('an unanswered phase completes with no faults', () async {
    final outcome = await usecase(
      session: buildSession(),
      phase: PmcsPhase.before,
      catalog: catalog,
      results: const {},
    );

    expect(outcome.faults, isEmpty);
    expect(outcome.session.isPhaseComplete(PmcsPhase.before), isTrue);
  });
}
