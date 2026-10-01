import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_history.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

import '../../support/fakes.dart';

void main() {
  PmcsHistory history(List<PmcsReport> reports, {DateTime? before}) =>
      PmcsHistory.forVehicle(reports,
          bumperNumber: 'a-11 ',
          uic: ' wj8taa',
          vehicleType: VehicleType.stryker,
          before: before);
  final old = buildReport(
      entityId: 'before-1',
      timestamp: DateTime.utc(2026, 3, 20),
      faults: [buildFault()]);

  test(
      'a clean AFTER leaves BEFORE faults suggested; a clean BEFORE clears them',
      () {
    final after = buildReport(entityId: 'after', phases: [PmcsPhase.after]);
    expect(history([after, old]).suggestedUnresolved.single.report, old);
    expect(history([buildReport(), old]).suggestedUnresolved, isEmpty);
    expect(history([after, old]).compare(PmcsPhase.after, []).previous, after);
  });

  test('bumper, UIC, platform and time isolate comparison baselines', () {
    final reports = [
      old,
      buildReport(entityId: 'other-unit', uic: 'OTHER'),
      buildReport(entityId: 'other-bumper', bumperNumber: 'B-22'),
      buildReport(entityId: 'other-platform', vehicleType: VehicleType.jltv),
      buildReport(entityId: 'future', timestamp: DateTime.utc(2026, 3, 26)),
    ];
    expect(
        history(reports, before: DateTime.utc(2026, 3, 24))
            .previousFor(PmcsPhase.before),
        old);
    expect(history([old], before: old.timestamp).reports, isEmpty);
  });

  test('unknown phase metadata cannot clear a prior fault or form a baseline',
      () {
    final legacy = buildReport(entityId: 'legacy', phases: []);
    expect(history([legacy, old]).suggestedUnresolved.single.report, old);
    expect(history([legacy]).compare(PmcsPhase.before, [buildFault()]).previous,
        isNull);
    expect(history([legacy]).compare(PmcsPhase.before, [buildFault()]).changes,
        isEmpty);
  });

  test(
      'comparison distinguishes new, recurring, changed, and no longer reported',
      () {
    final baseline = buildReport(faults: [
      buildFault(itemId: 'recurring'),
      buildFault(itemId: 'changed'),
      buildFault(itemId: 'gone'),
      buildFault(itemId: 'note', note: 'Old detail'),
    ]);
    final comparison = history([baseline]).compare(PmcsPhase.before, [
      buildFault(itemId: 'new'),
      buildFault(itemId: 'recurring'),
      buildFault(itemId: 'changed', severity: FaultSeverity.redX),
      buildFault(itemId: 'note', note: 'New detail'),
    ]);
    expect({
      for (final change in comparison.changes) change.fault.itemId: change.kind
    }, {
      'new': FaultChangeKind.newFault,
      'recurring': FaultChangeKind.recurring,
      'changed': FaultChangeKind.changed,
      'note': FaultChangeKind.changed,
      'gone': FaultChangeKind.noLongerReported,
    });
  });

  test('latest comparable phase is used, not the latest unrelated inspection',
      () {
    final after = buildReport(entityId: 'after', phases: [PmcsPhase.after]);
    final comparison = history([after, old]).compare(PmcsPhase.before, []);
    expect(comparison.previous, old);
    expect(comparison.changes.single.kind, FaultChangeKind.noLongerReported);
    expect(history([old]).compare(PmcsPhase.after, []).previous, isNull);
  });

  test('maintainer decisions do not replace the operator inspection baseline',
      () {
    final review = buildReport(
        entityId: 'review',
        maintainerReview: MaintainerReview(
          sourceReportId: old.entityId,
          faults: [
            FaultReview(
                itemId: old.faults.single.itemId,
                phase: PmcsPhase.before,
                verified: false)
          ],
          signature: buildSignature(),
        ));
    expect(history([review, old]).reports, [old]);
    expect(history([review, old]).suggestedUnresolved.single.report, old);
  });

  test('a newer observation has a new dismissal key and ordering is stable',
      () {
    final newer = buildReport(entityId: 'before-2', faults: old.faults);
    final first = history([old]).suggestedUnresolved.single;
    final second = history([old, newer]).suggestedUnresolved.single;
    expect(second.suggestionId, isNot(first.suggestionId));
    expect(second.report, newer);
    expect(history([newer, old]).suggestedUnresolved.single.suggestionId,
        second.suggestionId);
  });
}
