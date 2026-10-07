import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/presentation/reports/controllers/report_browser.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReportsViewModel model;
  late ReportBrowser browser;
  final old = DateTime.utc(2026, 10, 1);
  final middle = DateTime.utc(2026, 10, 2);
  final latest = DateTime.utc(2026, 10, 3);

  setUp(() async {
    model = FakeReportsViewModel();
    await model.suggestions.load();
    browser = ReportBrowser(model);
  });
  tearDown(() {
    model.suggestions.dispose();
    model.dispose();
  });

  Set<String> matches({
    FaultSeverity? severity,
    String search = '',
    bool faultsOnly = false,
    bool unreadOnly = false,
    List<PmcsReport>? source,
  }) =>
      browser
          .filterGroups(source ?? model.reports,
              search: search,
              faultsOnly: faultsOnly,
              unreadOnly: unreadOnly,
              severity: severity)
          .values
          .map((history) => history.first.entityId)
          .toSet();

  test('each severity matches any latest fault, including mixed-severity PMCS',
      () {
    for (final severity in FaultSeverity.values) {
      model.reports.add(buildReport(
          entityId: severity.wireName,
          bumperNumber: severity.wireName,
          faults: [buildFault(severity: severity)]));
    }
    model.reports.addAll([
      buildReport(entityId: 'mixed', bumperNumber: 'mixed', faults: [
        buildFault(itemId: 'brakes', severity: FaultSeverity.redX),
        buildFault(itemId: 'oil', severity: FaultSeverity.circleX),
        buildFault(itemId: 'light', severity: FaultSeverity.dash),
      ]),
      buildReport(entityId: 'clean', bumperNumber: 'clean'),
    ]);

    expect(matches(severity: FaultSeverity.redX), {'RED_X', 'mixed'});
    expect(matches(severity: FaultSeverity.circleX), {'CIRCLE_X', 'mixed'});
    expect(matches(severity: FaultSeverity.dash), {'DASH', 'mixed'});
    expect(matches(severity: FaultSeverity.circleX, faultsOnly: true),
        {'CIRCLE_X', 'mixed'});
  });

  test('clean or reclassified latest phase supersedes its older RED X', () {
    model.reports.addAll([
      buildReport(
          entityId: 'resolved-old',
          bumperNumber: 'A-11',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'resolved-now', bumperNumber: 'A-11', timestamp: latest),
      buildReport(
          entityId: 'reclassified-old',
          bumperNumber: 'B-22',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'reclassified-now',
          bumperNumber: 'B-22',
          timestamp: latest,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
    ]);

    expect(matches(severity: FaultSeverity.redX), isEmpty);
    expect(matches(severity: FaultSeverity.circleX), {'reclassified-now'});
    expect(matches(faultsOnly: true), {'reclassified-now'});
  });

  test('unresolved other-phase severity matches until dismissed, then restores',
      () async {
    final earlier = buildReport(
        entityId: 'before',
        timestamp: old,
        faults: [buildFault(severity: FaultSeverity.redX)]);
    final current = buildReport(entityId: 'after', timestamp: latest, phases: [
      PmcsPhase.after
    ], faults: [
      buildFault(phase: PmcsPhase.after, severity: FaultSeverity.dash),
    ]);
    model.reports.addAll([earlier, current]);
    final suggestion = browser.visibleSuggestionsFor(current).single;

    expect(matches(severity: FaultSeverity.redX), {'after'});
    expect(matches(severity: FaultSeverity.dash), {'after'});
    await model.suggestions.setDismissed(suggestion.suggestionId, true);
    expect(matches(severity: FaultSeverity.redX), isEmpty);
    expect(matches(severity: FaultSeverity.dash), {'after'});
    expect(matches(faultsOnly: true), {'after'});
    await model.suggestions.setDismissed(suggestion.suggestionId, false);
    expect(matches(severity: FaultSeverity.redX), {'after'});
    expect(earlier.faults.single.severity, FaultSeverity.redX);
    expect(current.faults.single.severity, FaultSeverity.dash);
  });

  test('a newer inspection of a historical phase replaces obsolete severity',
      () {
    model.reports.addAll([
      buildReport(
          entityId: 'old-before',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'new-before',
          timestamp: middle,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
      buildReport(
          entityId: 'latest-after',
          timestamp: latest,
          phases: [PmcsPhase.after]),
    ]);

    expect(matches(severity: FaultSeverity.redX), isEmpty);
    expect(matches(severity: FaultSeverity.circleX), {'latest-after'});
    expect(matches(severity: FaultSeverity.dash), isEmpty);
  });

  test(
      'unrelated UIC, vehicle type, bumper, review and future faults do not leak',
      () {
    final current = buildReport(
        entityId: 'clean-primary',
        timestamp: latest,
        phases: [PmcsPhase.after]);
    final otherUnit = buildReport(
        entityId: 'clean-other',
        uic: 'WAB4C0',
        timestamp: latest,
        phases: [PmcsPhase.after]);
    model.reports.addAll([
      current,
      otherUnit,
      buildReport(
          entityId: 'other-unit-before',
          uic: 'WAB4C0',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'other-type-before',
          vehicleType: VehicleType.jltv,
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'other-bumper-before',
          bumperNumber: 'B-22',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'future-before',
          timestamp: latest.add(const Duration(days: 1)),
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'review-before',
          timestamp: old,
          faults: [buildFault(severity: FaultSeverity.redX)],
          maintainerReview: MaintainerReview(
            sourceReportId: current.entityId,
            faults: const [
              FaultReview(
                  itemId: 'B-ENG-01', phase: PmcsPhase.before, verified: true)
            ],
            signature: buildSignature(),
          )),
    ]);

    expect(matches(severity: FaultSeverity.redX, source: [current]), isEmpty);
    expect(matches(severity: FaultSeverity.redX, source: [otherUnit]),
        {'clean-other'});
    expect(matches(severity: FaultSeverity.redX, source: [current, otherUnit]),
        {'clean-other'});
  });

  test('severity combines with search, unread, faults and selected UIC by AND',
      () {
    model.reports.addAll([
      buildReport(
          entityId: 'matching',
          bumperNumber: 'A-11',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'different-severity',
          bumperNumber: 'A-12',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
      buildReport(
          entityId: 'already-read',
          bumperNumber: 'A-13',
          isOutgoing: false,
          isRead: true,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'different-bumper',
          bumperNumber: 'B-22',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'different-unit',
          bumperNumber: 'A-11',
          uic: 'WAB4C0',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.redX)]),
    ]);
    final selectedUnit =
        model.reports.where((report) => report.uic == 'WJ8TAA').toList();

    expect(
        matches(
            severity: FaultSeverity.redX,
            search: ' a- ',
            unreadOnly: true,
            faultsOnly: true,
            source: selectedUnit),
        {'matching'});
    expect(
        matches(
            severity: FaultSeverity.redX,
            search: ' wab4c0 ',
            unreadOnly: true,
            faultsOnly: true,
            source: selectedUnit),
        isEmpty);
    expect(
        matches(
            search: 'a-',
            unreadOnly: true,
            faultsOnly: true,
            source: selectedUnit),
        {'matching', 'different-severity'});
  });

  test('no severity preserves all vehicles or the existing With faults scope',
      () async {
    final clean = buildReport(entityId: 'clean', bumperNumber: 'A-11');
    final oldFault = buildReport(
        entityId: 'earlier',
        bumperNumber: 'B-22',
        timestamp: old,
        faults: [buildFault(severity: FaultSeverity.circleX)]);
    final withSuggestion = buildReport(
        entityId: 'suggested',
        bumperNumber: 'B-22',
        timestamp: latest,
        phases: [PmcsPhase.after]);
    model.reports.addAll([clean, oldFault, withSuggestion]);

    expect(matches(), {'clean', 'suggested'});
    expect(matches(faultsOnly: true), {'suggested'});
    final suggestion = browser.visibleSuggestionsFor(withSuggestion).single;
    await model.suggestions.setDismissed(suggestion.suggestionId, true);
    expect(matches(faultsOnly: true), isEmpty);
    expect(matches(), {'clean', 'suggested'});
  });
}
