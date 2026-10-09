import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/followed_unit.dart';
import 'package:circle_x/presentation/reports/reports_page.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

class UnitReportsFake extends FakeReportsViewModel {
  void refreshUnits() => notifyListeners();
}

void main() {
  late UnitReportsFake viewModel;
  const alpha = (bumperNumber: 'A11', uic: 'WJ8TAA');
  const bravo = (bumperNumber: 'A11', uic: 'WAB4C0');
  const other = (bumperNumber: 'C33', uic: 'WXYZ00');

  setUp(() async {
    await getIt.reset();
    viewModel = UnitReportsFake()
      ..myUic = 'WJ8TAA'
      ..reportUnits = const [
        FollowedUnit(uic: 'WJ8TAA', name: 'Alpha'),
        FollowedUnit(uic: 'WAB4C0', name: 'Bravo'),
      ];
    viewModel.reports.addAll([
      buildReport(
          entityId: 'alpha',
          bumperNumber: 'A-11',
          uic: 'WJ8TAA',
          isOutgoing: false),
      buildReport(
          entityId: 'bravo',
          bumperNumber: 'A-11',
          uic: ' wa b4\tc0 ',
          isOutgoing: false),
      buildReport(
          entityId: 'other',
          bumperNumber: 'C-33',
          uic: 'WXYZ00',
          isOutgoing: false),
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

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('report-unit-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'all followed units and a named unit keep matching bumpers separate',
      (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey(alpha)), findsOneWidget);
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);
    expect(find.byKey(const ValueKey(other)), findsNothing);

    await select(tester, 'Bravo (WAB4C0)');
    expect(find.byKey(const ValueKey(alpha)), findsNothing);
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(bravo)));
    await tester.pumpAndSettle();
    expect(find.text('UIC WAB4C0 · 1 PMCS'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to vehicles'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(alpha)), findsNothing);
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);

    await select(tester, 'All my units');
    expect(find.byKey(const ValueKey(alpha)), findsOneWidget);
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);
  });

  testWidgets(
      'changing local names updates options and unfollowing resets selection',
      (tester) async {
    await open(tester);
    await select(tester, 'Bravo (WAB4C0)');
    viewModel.reportUnits = const [
      FollowedUnit(uic: 'WJ8TAA', name: 'Alpha'),
      FollowedUnit(uic: 'WAB4C0', name: 'Bravo Company'),
    ];
    // Simulate the profile-save notification received by the mounted page.
    viewModel.refreshUnits();
    await tester.pumpAndSettle();
    expect(find.text('Bravo Company (WAB4C0)'), findsOneWidget);

    viewModel.reportUnits = const [FollowedUnit(uic: 'WJ8TAA', name: 'Alpha')];
    viewModel.refreshUnits();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(alpha)), findsOneWidget);
    expect(find.byKey(const ValueKey(bravo)), findsNothing);
    expect(tester.takeException(), isNull);
    await select(tester, 'Other units');
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);
    expect(find.byKey(const ValueKey(other)), findsOneWidget);
  });

  testWidgets('the unit selection combines with search', (tester) async {
    await open(tester);
    await select(tester, 'Bravo (WAB4C0)');
    await tester.enterText(find.byType(TextField), 'WJ8TAA');
    await tester.pumpAndSettle();
    expect(
        find.text('No vehicles match your search or filters.'), findsOneWidget);
    expect(find.byKey(const ValueKey(alpha)), findsNothing);
    await tester.enterText(find.byType(TextField), 'wa b4 c0');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(bravo)), findsOneWidget);
  });

  testWidgets('long local unit names fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const label =
        'A very long local unit name for the attached maintenance company';
    viewModel.reportUnits = const [FollowedUnit(uic: 'WJ8TAA', name: label)];
    await open(tester);
    await select(tester, '$label (WJ8TAA)');
    expect(find.byKey(const ValueKey(alpha)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
