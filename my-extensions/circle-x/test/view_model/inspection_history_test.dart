import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_history.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/presentation/common/services/fault_suggestion_controller.dart';
import '../support/cac_fixtures.dart';
import '../support/fakes.dart';
import '../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;
  setUp(() {
    harness = InspectionHarness();
    harness.reports.reports.add(buildReport(
      entityId: 'previous',
      timestamp: DateTime.utc(2026, 3, 20),
      faults: [
        buildFault(
            itemId: brakeFluid.id,
            condition: 'Reservoir Cracked',
            severity: FaultSeverity.redX,
            note: 'Leak at seam')
      ],
    ));
  });
  tearDown(() {
    harness.viewModel.dispose();
    clearSnackBars();
  });

  test(
      'withdrawn history is excluded and unavailable history does not block PMCS',
      () async {
    harness.reports.withdrawnIds.add('previous');
    await harness.beginPhase(PmcsPhase.before);
    expect(harness.viewModel.history!.reports, isEmpty);
    await harness.viewModel.resetToSetup();
    harness.reports.failHistoryRead = true;
    await harness.walkToSummary();
    expect(harness.viewModel.historyUnavailable, isTrue);
    expect(harness.viewModel.history, isNull);
    expect(harness.viewModel.session!.completedPhases, [PmcsPhase.before]);
  });

  test(
      'prior RED X is advisory; serviceable answer overrides it and survives resume',
      () async {
    await harness.beginPhase(PmcsPhase.before);
    final model = harness.viewModel;
    expect(model.history!.suggestedUnresolved, hasLength(1));
    expect(model.results, isEmpty);
    expect(model.phaseTally.isDeadlined, isFalse);
    await model.answer(brakeFluid, 0);
    await model.answer(parkingBrake, 0);
    await model.completeActivePhase();
    final draft = model.session!;
    await model.resetToSetup();
    await model.resumeSession(draft);
    expect(model.summarySuggestions, isEmpty);
    expect(model.comparisons.single.changes.single.kind,
        FaultChangeKind.noLongerReported);
    harness.cacScanner.willRead(cacBarcode());
    await model.scanCac();
    await model.submit();
    final report = harness.reports.reports.last;
    expect(report.faults, isEmpty);
    expect(report.isDeadlined, isFalse);
  });

  test('an unrelated PMCS can submit with an undismissed suggestion', () async {
    await harness.walkToSummary(phase: PmcsPhase.after);
    final model = harness.viewModel;
    expect(model.summarySuggestions, hasLength(1));
    expect(model.sessionTally.isEmpty, isTrue);
    expect(model.comparisons.single.previous, isNull);
    harness.cacScanner.willRead(cacBarcode());
    await model.scanCac();
    await model.submit();
    expect(harness.reports.reports.last.faults, isEmpty);
  });

  test(
      'dismiss and restore persist without changing findings; failed saves keep state',
      () async {
    await harness.beginPhase(PmcsPhase.before);
    final model = harness.viewModel;
    final suggestion = model.history!.suggestedUnresolved.single;
    await model.suggestions.setDismissed(suggestion.suggestionId, true);
    final restarted = FaultSuggestionController(harness.reports);
    addTearDown(restarted.dispose);
    await restarted.load();
    expect(restarted.dismissed, contains(suggestion.suggestionId));
    expect(model.results, isEmpty);
    expect(harness.reports.reports.single.faults.single.severity,
        FaultSeverity.redX);
    harness.reports.failSuggestionSave = true;
    await restarted.setDismissed(suggestion.suggestionId, false);
    expect(restarted.dismissed, contains(suggestion.suggestionId));
    harness.reports.failSuggestionSave = false;
    await restarted.setDismissed(suggestion.suggestionId, false);
    expect(restarted.dismissed, isEmpty);
    expect(harness.reports.dismissedSuggestions, isEmpty);
  });
}
