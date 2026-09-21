import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/session/record_check_result.dart';

import '../../../support/fakes.dart';

const item = PmcsCheckItem(
  id: 'B-BRK-01',
  item: 'Brake Fluid',
  check: 'Reservoir between MIN and MAX',
  faults: ['Level OK', 'Low', 'Empty', 'Reservoir Cracked'],
);

void main() {
  late FakeResultsRepository results;
  late RecordCheckResult usecase;

  setUp(() {
    results = FakeResultsRepository();
    usecase = RecordCheckResult(
      repository: results,
      classifier: FakeFaultClassifier(criticalIds: const {'B-BRK-01'}),
      clock: FixedClock(DateTime.utc(2026, 3, 24, 7)),
    );
  });

  test('a serviceable answer carries no severity', () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 0,
    );

    expect(result.isServiceable, isTrue);
    expect(result.severity, isNull);
    expect(result.faultLabel, 'Level OK');
  });

  test('resolves the label off the item, not the caller', () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 3,
    );

    expect(result.faultLabel, 'Reservoir Cracked');
  });

  test('grades through the classifier', () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 3,
    );

    expect(result.severity, FaultSeverity.redX);
  });

  test('writes through on every answer', () async {
    await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 1,
    );

    final stored = await results.getResults('session-1', PmcsPhase.before);
    expect(stored['B-BRK-01']?.faultIndex, 1);
  });

  test('re-answering replaces the previous answer', () async {
    await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 1,
    );
    await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 0,
    );

    final stored = await results.getResults('session-1', PmcsPhase.before);
    expect(stored, hasLength(1));
    expect(stored['B-BRK-01']?.faultIndex, 0);
  });

  test('keeps a dictated note with the answer', () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 2,
      note: 'reservoir bone dry',
    );

    expect(result.note, 'reservoir bone dry');
  });

  test('stamps the time from the clock', () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 1,
    );

    expect(result.recordedAt, DateTime.utc(2026, 3, 24, 7));
  });

  test('keeps phases separate', () async {
    await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 1,
    );

    final after = await results.getResults('session-1', PmcsPhase.after);
    expect(after, isEmpty);
  });

  test('an out-of-range index yields an empty label rather than throwing',
      () async {
    final result = await usecase(
      sessionId: 'session-1',
      phase: PmcsPhase.before,
      item: item,
      faultIndex: 99,
    );

    expect(result.faultLabel, '');
  });
}
