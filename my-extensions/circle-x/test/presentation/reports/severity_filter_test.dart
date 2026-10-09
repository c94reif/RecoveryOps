import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/followed_unit.dart';
import 'package:circle_x/presentation/reports/reports_page.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReportsViewModel viewModel;

  setUp(() async {
    await getIt.reset();
    viewModel = FakeReportsViewModel()
      ..myUic = 'WJ8TAA'
      ..reportUnits = const [
        FollowedUnit(uic: 'WJ8TAA', name: 'Alpha'),
        FollowedUnit(uic: 'WAB4C0', name: 'Bravo'),
      ];
    viewModel.reports.addAll([
      buildReport(
          entityId: 'red',
          bumperNumber: 'A-11',
          isOutgoing: false,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'x',
          bumperNumber: 'B-22',
          uic: 'WAB4C0',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
      buildReport(
          entityId: 'dash',
          bumperNumber: 'C-33',
          isOutgoing: false,
          faults: [buildFault(severity: FaultSeverity.dash)]),
      buildReport(entityId: 'clean', bumperNumber: 'D-44', isOutgoing: false),
    ]);
    getIt.registerSingleton<ReportsViewModel>(viewModel);
  });

  tearDown(() async {
    await getIt.reset();
    viewModel.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: ReportsPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MY UNITS'));
    await tester.pumpAndSettle();
  }

  Future<void> selectSeverity(WidgetTester tester, String severity) async {
    final chip = find.byKey(ValueKey('severity-$severity'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('severity chips filter RED X, X and DASH independently',
      (tester) async {
    await open(tester);
    await selectSeverity(tester, 'CIRCLE_X');
    expect(find.text('B-22 - Stryker'), findsOneWidget);
    expect(find.text('A-11 - Stryker'), findsNothing);
    expect(find.text('C-33 - Stryker'), findsNothing);
    expect(find.text('D-44 - Stryker'), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('severity-CIRCLE_X')),
            matching: find.text('X')),
        findsOneWidget);

    await selectSeverity(tester, 'RED_X');
    expect(find.text('A-11 - Stryker'), findsOneWidget);
    expect(find.text('B-22 - Stryker'), findsNothing);
    await selectSeverity(tester, 'DASH');
    expect(find.text('C-33 - Stryker'), findsOneWidget);
    expect(find.text('A-11 - Stryker'), findsNothing);

    await selectSeverity(tester, 'DASH');
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('severity-all')))
            .selected,
        isTrue);
    expect(find.text('A-11 - Stryker'), findsOneWidget);
  });

  testWidgets(
      'severity combines with the named unit, search and unread filters',
      (tester) async {
    viewModel.reports.addAll([
      buildReport(
          entityId: 'other-x',
          bumperNumber: 'E-55',
          isOutgoing: false,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
      buildReport(
          entityId: 'read-x',
          bumperNumber: 'F-66',
          uic: 'WAB4C0',
          isOutgoing: false,
          isRead: true,
          faults: [buildFault(severity: FaultSeverity.circleX)]),
    ]);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('report-unit-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bravo (WAB4C0)').last);
    await tester.pumpAndSettle();
    await selectSeverity(tester, 'CIRCLE_X');
    await tester.ensureVisible(find.text('With faults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With faults'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unread'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('B-22 - Stryker'), findsOneWidget);
    expect(find.text('E-55 - Stryker'), findsNothing);
    expect(find.text('F-66 - Stryker'), findsNothing);

    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(
        find.text('No vehicles match your search or filters.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('severity-all')))
            .selected,
        isTrue);
    expect(find.text('B-22 - Stryker'), findsOneWidget);
    expect(find.text('F-66 - Stryker'), findsOneWidget);
    expect(find.text('E-55 - Stryker'), findsNothing);
    expect(find.text('Bravo (WAB4C0)'), findsOneWidget);
  });

  testWidgets('a severity-filtered vehicle still opens its entire history',
      (tester) async {
    viewModel.reports.add(buildReport(
        entityId: 'prior-x',
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        isOutgoing: false,
        timestamp: DateTime.utc(2020),
        faults: [buildFault(severity: FaultSeverity.dash)]));
    await open(tester);
    await selectSeverity(tester, 'CIRCLE_X');
    final vehicle =
        find.byKey(const ValueKey((bumperNumber: 'B22', uic: 'WAB4C0')));
    await tester.ensureVisible(vehicle);
    await tester.tap(vehicle);
    await tester.pumpAndSettle();
    expect(find.text('UIC WAB4C0 · 2 PMCS'), findsOneWidget);
    expect(find.byKey(const ValueKey('x')), findsOneWidget);
    expect(find.byKey(const ValueKey('prior-x')), findsOneWidget);
    await tester.tap(find.byTooltip('Back to vehicles'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('severity-CIRCLE_X')))
            .selected,
        isTrue);
  });

  testWidgets('severity choices wrap on narrow phones with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await selectSeverity(tester, 'RED_X');
    expect(tester.takeException(), isNull);
    final clear = find.text('Clear filters');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('severity-all')))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
