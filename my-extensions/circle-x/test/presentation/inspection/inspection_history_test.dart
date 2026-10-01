import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/presentation/inspection/inspection_page.dart';
import 'package:circle_x/presentation/inspection/summary_page.dart';

import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    harness = InspectionHarness();
    harness.register();
    harness.reports.reports.add(buildReport(
      entityId: 'prior-before',
      timestamp: DateTime.utc(2026, 3, 20),
      faults: [
        buildFault(
            itemId: brakeFluid.id,
            subcategory: 'Brake Fluid',
            condition: 'Reservoir Cracked',
            severity: FaultSeverity.redX,
            note: 'Leak at seam')
      ],
    ));
  });

  tearDown(() async {
    await getIt.reset();
    harness.viewModel.dispose();
    clearSnackBars();
  });

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'previous finding can be dismissed, restored, accepted and overridden',
      (tester) async {
    tester.view.physicalSize = const Size(370, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await harness.beginPhase(PmcsPhase.before);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: InspectionPage())));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Previously: Reservoir Cracked'), findsOneWidget);
    expect(find.text('Previous note: Leak at seam'), findsOneWidget);
    expect(harness.viewModel.results, isEmpty);
    await tap(tester, 'Dismiss suggestion');
    expect(find.textContaining('Previously: Reservoir Cracked'), findsNothing);
    expect(harness.viewModel.results, isEmpty);
    await tap(tester, 'Restore previous suggestion');
    await tap(tester, 'Still present');
    expect(harness.viewModel.results[brakeFluid.id]!.faultIndex, 3);
    expect(harness.viewModel.results[brakeFluid.id]!.note, 'Leak at seam');
    harness.viewModel.expandItem(brakeFluid.id);
    await tester.pumpAndSettle();
    await tap(tester, 'LEVEL OK');
    expect(harness.viewModel.results[brakeFluid.id]!.isServiceable, isTrue);
    expect(harness.viewModel.results[brakeFluid.id]!.note, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'review shows same-type changes and suggestions fit enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await harness.walkToSummary();
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: const Scaffold(body: SummaryPage()),
    ));
    await tester.pumpAndSettle();
    final changes = find.text('Changes since previous PMCS');
    await tester.scrollUntilVisible(changes, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(changes);
    await tester.pumpAndSettle();
    expect(find.text('No longer reported · Brake Fluid'), findsOneWidget);
    expect(harness.viewModel.sessionTally.isEmpty, isTrue);
    expect(tester.takeException(), isNull);

    await harness.viewModel.resetToSetup();
    await harness.walkToSummary(phase: PmcsPhase.after);
    await tester.pumpAndSettle();
    expect(find.text('Suggested unresolved faults · 1'), findsOneWidget);
    await tap(tester, 'Dismiss suggestion');
    expect(harness.viewModel.suggestions.dismissed, hasLength(1));
    await tap(tester, 'Dismissed suggestions (1)');
    await tap(tester, 'Restore suggestion');
    expect(harness.viewModel.suggestions.dismissed, isEmpty);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Suggested unresolved faults · 1'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Suggested unresolved faults · 1'), findsOneWidget);
    expect(harness.viewModel.sessionFaults, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
