import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/reports/reports_page.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReportsViewModel model;
  setUp(() async {
    await getIt.reset();
    model = FakeReportsViewModel();
    getIt.registerSingleton<ReportsViewModel>(model);
    model.reports.addAll([
      buildReport(
          entityId: 'prior-before',
          isOutgoing: false,
          timestamp: DateTime.utc(2026, 3, 20),
          faults: [buildFault()]),
      buildReport(
          entityId: 'latest-after',
          phases: [PmcsPhase.after],
          timestamp: DateTime.utc(2026, 3, 24)),
    ]);
  });
  tearDown(() async {
    await getIt.reset();
    model.suggestions.dispose();
    model.dispose();
  });

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'earlier received faults remain advisory on a clean local vehicle and can be overridden',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: ReportsPage())));
    await tester.pumpAndSettle();
    expect(find.text('Latest report: FMC'), findsOneWidget);
    expect(find.text('1 earlier fault suggested for review'), findsOneWidget);
    await tap(tester, 'With faults');
    expect(find.text('A-11 - Stryker'), findsOneWidget);
    await tap(tester, 'A-11 - Stryker');
    expect(find.text('Suggested unresolved faults · 1'), findsOneWidget);
    await tap(tester, 'Dismiss suggestion');
    expect(find.text('Dismissed suggestions (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to vehicles'));
    await tester.pumpAndSettle();
    expect(
        find.text('No vehicles match your search or filters.'), findsOneWidget);
    await tap(tester, 'Clear filters');
    expect(find.text('Latest report: FMC'), findsOneWidget);
    await tap(tester, 'A-11 - Stryker');
    await tap(tester, 'Dismissed suggestions (1)');
    await tap(tester, 'Restore suggestion');
    expect(find.text('Suggested unresolved faults · 1'), findsOneWidget);
    expect(model.reports.first.faults, hasLength(1));
    expect(model.reports.last.faults, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report comparisons use received history of the same type',
      (tester) async {
    model.reports.removeLast();
    model.reports.add(buildReport(
        entityId: 'latest-before', timestamp: DateTime.utc(2026, 3, 24)));
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: ReportsPage())));
    await tester.pumpAndSettle();
    await tap(tester, 'A-11 - Stryker');
    await tap(tester, 'View changes');
    expect(find.text('Changes since previous PMCS'), findsOneWidget);
    expect(find.text('No longer reported · Engine Oil Level'), findsOneWidget);
    expect(find.textContaining('Before Operations · compared with'),
        findsOneWidget);
    expect(find.textContaining('Suggested unresolved faults'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
