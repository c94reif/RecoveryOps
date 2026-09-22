import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';
import 'package:ivy_pulse/presentation/inspection/check_item_card.dart';

import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

void main() {
  late FakeFaultClassifier classifier;
  late List<int> answered;
  late int expandCalls;
  late int collapseCalls;
  late int dictateCalls;

  setUp(() {
    classifier = FakeFaultClassifier(criticalIds: const {'B-BRK-01'});
    answered = [];
    expandCalls = 0;
    collapseCalls = 0;
    dictateCalls = 0;
  });

  CheckResult resultFor(int faultIndex, {String? note}) {
    return CheckResult(
      itemId: brakeFluid.id,
      faultIndex: faultIndex,
      faultLabel: brakeFluid.labelAt(faultIndex),
      severity: classifier.classify(
        itemId: brakeFluid.id,
        faultIndex: faultIndex,
      ),
      note: note,
      recordedAt: DateTime.utc(2026, 3, 24, 7),
    );
  }

  // The card is hosted in a scroll view because that is how InspectionPage
  // hosts it: a check has to survive being handed an unbounded height.
  Widget createWidgetUnderTest({
    CheckResult? result,
    bool isExpanded = true,
    bool isDictating = false,
  }) {
    return MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: ListView(
          children: [
            CheckItemCard(
              item: brakeFluid,
              result: result,
              isExpanded: isExpanded,
              isDictating: isDictating,
              classifier: classifier,
              onAnswer: answered.add,
              onExpand: () => expandCalls++,
              onCollapse: () => collapseCalls++,
              onDictateNote: () => dictateCalls++,
            ),
          ],
        ),
      ),
    );
  }

  group('an open check', () {
    testWidgets('shows the TM id, the component and the TM instruction',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('B-BRK-01'), findsOneWidget);
      expect(find.text('Brake Fluid'), findsOneWidget);
      expect(find.text('Reservoir between MIN and MAX'), findsOneWidget);
    });

    testWidgets('offers every condition in the TM, serviceable included',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('LEVEL OK'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('Reservoir Cracked'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(4));
    });

    testWidgets('grades every fault option before it is chosen',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Low and Empty are DASH on this item; Reservoir Cracked deadlines it.
      expect(find.text('DASH'), findsNWidgets(2));
      expect(find.text('RED X'), findsOneWidget);
    });

    testWidgets('sets the serviceable option apart from the fault options',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Serviceable is the commonest answer, so it is upper-cased, iconed and
      // owns a full-width row of its own.
      final serviceable = find.widgetWithText(OutlinedButton, 'LEVEL OK');
      expect(
        find.descendant(
          of: serviceable,
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('RESERVOIR CRACKED'), findsNothing);

      final serviceableWidth = tester.getSize(serviceable).width;
      final faultWidth =
          tester.getSize(find.widgetWithText(OutlinedButton, 'Low')).width;
      expect(serviceableWidth, greaterThan(faultWidth));
    });

    testWidgets('carries no severity banner and no note row until answered',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(SeverityBadge), findsNothing);
      expect(find.text('Tap to dictate a note'), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });

    testWidgets('cannot be folded away before it is answered', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Brake Fluid'));
      await tester.pump();

      expect(collapseCalls, 0);
    });
  });

  group('answering', () {
    testWidgets('tapping a fault option answers with its index',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Empty'));
      await tester.pump();

      expect(answered, [2]);
    });

    testWidgets('tapping the worst condition answers with its index',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Reservoir Cracked'));
      await tester.pump();

      expect(answered, [3]);
    });

    testWidgets('tapping serviceable answers with index zero', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('LEVEL OK'));
      await tester.pump();

      expect(answered, [0]);
    });

    testWidgets('an answered check can be re-answered with no confirm step',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(2)));

      await tester.tap(find.text('LEVEL OK'));
      await tester.pump();

      expect(answered, [0]);
    });
  });

  group('a faulted check', () {
    testWidgets('banners the severity alongside the condition chosen',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(3)));

      expect(find.text('RED X — Reservoir Cracked'), findsOneWidget);
      expect(find.byIcon(severityIcon(FaultSeverity.redX)), findsOneWidget);
    });

    testWidgets('shows the dictated note once one is attached', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          result: resultFor(3, note: 'reservoir bone dry, fluid on the hub'),
        ),
      );

      expect(find.text('reservoir bone dry, fluid on the hub'), findsOneWidget);
      expect(find.text('Tap to dictate a note'), findsNothing);
    });

    testWidgets('invites a note while it has none', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(1)));

      expect(find.text('Optional description · up to 155 characters'),
          findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byTooltip('Tap to record'), findsOneWidget);
    });

    testWidgets('asks for dictation when the mic is tapped', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(1)));

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      expect(dictateCalls, 1);
    });

    testWidgets('reads as recording while the mic is live', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(1), isDictating: true),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byTooltip('Recording — tap to stop'), findsOneWidget);
    });

    testWidgets('a serviceable answer keeps the banner and the note row away',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(0)));

      expect(find.textContaining('—'), findsNothing);
      expect(find.text('Tap to dictate a note'), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
    });
  });

  group('a collapsed check', () {
    testWidgets('folds a serviceable answer down to its id, component and OK',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(0), isExpanded: false),
      );

      expect(find.text('B-BRK-01'), findsOneWidget);
      expect(find.text('Brake Fluid'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Reservoir between MIN and MAX'), findsNothing);
      expect(find.text('LEVEL OK'), findsNothing);
    });

    testWidgets('keeps the severity and the condition of a faulted answer',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(3), isExpanded: false),
      );

      expect(find.byType(SeverityBadge), findsOneWidget);
      expect(find.text('RED X'), findsOneWidget);
      expect(find.text('Reservoir Cracked'), findsOneWidget);
      expect(find.byIcon(severityIcon(FaultSeverity.redX)), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('separates a DASH answer from a deadlining one',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(1), isExpanded: false),
      );

      expect(find.text('DASH'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(severityIcon(FaultSeverity.dash)), findsOneWidget);
      expect(find.byIcon(severityIcon(FaultSeverity.redX)), findsNothing);
    });

    testWidgets('opens again when tapped', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(1), isExpanded: false),
      );

      await tester.tap(find.text('Brake Fluid'));
      await tester.pump();

      expect(expandCalls, 1);
      expect(collapseCalls, 0);
    });

    testWidgets('closes again when its reopened header is tapped',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(result: resultFor(1)));

      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.text('Brake Fluid'));
      await tester.pump();

      expect(collapseCalls, 1);
      expect(expandCalls, 0);
    });

    testWidgets('offers no answer buttons while it is folded', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(result: resultFor(1), isExpanded: false),
      );

      expect(find.byType(OutlinedButton), findsNothing);
      expect(answered, isEmpty);
    });
  });
}
