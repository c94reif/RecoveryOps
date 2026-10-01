import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_summary.dart';

import '../../support/fakes.dart';

void main() {
  final review = MaintainerReview(
    sourceReportId: 'original',
    signature: buildSignature(),
    faults: const [
      FaultReview(
          itemId: 'shared-check',
          phase: PmcsPhase.before,
          verified: true,
          description: 'Confirmed before departure.'),
      FaultReview(
          itemId: 'shared-check',
          phase: PmcsPhase.after,
          verified: false,
          description: 'No leak after operation.'),
      FaultReview(itemId: 'unknown', phase: PmcsPhase.after, verified: false),
    ],
  );

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: Scaffold(
            body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: MaintainerReviewSummary(review: review, faults: [
            buildFault(
                itemId: 'shared-check',
                phase: PmcsPhase.before,
                subcategory: 'Engine oil',
                condition: 'Low'),
            buildFault(
                itemId: 'shared-check',
                phase: PmcsPhase.after,
                subcategory: 'Engine oil',
                condition: 'Leak'),
          ]),
        )),
      );

  Future<void> toggle(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'signed summary expands phase-matched faults and maintainer notes',
      (tester) async {
    await tester.pumpWidget(subject());
    expect(find.text('1 verified'), findsOneWidget);
    expect(find.text('2 not verified'), findsOneWidget);
    expect(find.textContaining('CAC signed by'), findsOneWidget);
    expect(find.textContaining('Confirmed before departure.'), findsNothing);
    await toggle(tester, 'View review details (3)');
    expect(find.text('Engine oil — Low'), findsOneWidget);
    expect(find.text('Engine oil — Leak'), findsOneWidget);
    expect(find.text('BEFORE · shared-check'), findsOneWidget);
    expect(find.text('AFTER · shared-check'), findsOneWidget);
    expect(find.text('Maintainer note: Confirmed before departure.'),
        findsOneWidget);
    expect(
        find.text('Maintainer note: No leak after operation.'), findsOneWidget);
    expect(find.text('Fault unknown'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Not verified'), findsNWidgets(2));
    await toggle(tester, 'Hide review details');
    expect(find.text('Engine oil — Low'), findsNothing);
    expect(find.textContaining('CAC signed by'), findsOneWidget);
  });

  testWidgets('review badges and notes fit a narrow panel with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await toggle(tester, 'View review details (3)');
    await tester.ensureVisible(find.text('Fault unknown'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await toggle(tester, 'Hide review details');
    expect(tester.takeException(), isNull);
  });
}
