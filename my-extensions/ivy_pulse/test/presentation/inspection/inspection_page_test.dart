import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/phase_progress_bar.dart';
import 'package:ivy_pulse/presentation/inspection/check_item_card.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_page.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

import '../../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    harness = InspectionHarness();
    harness.register();
  });

  tearDown(() async {
    await getIt.reset();
    clearSnackBars();
  });

  /// A full-height EUD: every check in the phase has to be laid out and
  /// tappable, which is exactly how the operator sees it.
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: InspectionPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps an answer on a check exactly as a gloved thumb would.
  Future<void> answer(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  final completeButton = find.byType(CustomButton);

  group('the phase header', () {
    testWidgets('carries the bumper number, the phase and the progress',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.byType(PhaseProgressBar), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('names whichever phase is actually being walked',
        (tester) async {
      await harness.beginPhase(PmcsPhase.during);
      await pumpPage(tester);

      expect(find.text('DURING'), findsOneWidget);
      expect(find.text('BEFORE'), findsNothing);
      expect(find.text('0/1'), findsOneWidget);
    });

    testWidgets('the progress climbs as checks are answered', (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'LEVEL OK');

      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('0/2'), findsNothing);
    });

    testWidgets('the running fault tally only appears once one is found',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(find.byType(FaultTallyBar), findsNothing);

      await answer(tester, 'Reservoir Cracked');

      expect(find.byType(FaultTallyBar), findsOneWidget);
      expect(find.text('1 FAULT'), findsOneWidget);
      expect(find.text('RED X: 1'), findsOneWidget);
    });

    testWidgets('shows nothing at all until a phase is open', (tester) async {
      await harness.begin();
      await pumpPage(tester);

      expect(find.byType(CheckItemCard), findsNothing);
      expect(find.byType(PhaseProgressBar), findsNothing);
      expect(find.byTooltip('Back to phases'), findsNothing);
    });
  });

  group('the checklist', () {
    testWidgets('renders every walk-around station as its own section',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(find.text('BRAKES'), findsOneWidget);
      expect(find.byType(CheckItemCard), findsNWidgets(2));
    });

    testWidgets('every check in the station is there, in TM order',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(find.text('B-BRK-01'), findsOneWidget);
      expect(find.text('Brake Fluid'), findsOneWidget);
      expect(find.text('B-BRK-02'), findsOneWidget);
      expect(find.text('Parking Brake'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('B-BRK-01')).dy,
        lessThan(tester.getTopLeft(find.text('B-BRK-02')).dy),
      );
    });

    testWidgets('a station from another phase never bleeds in', (tester) async {
      await harness.beginPhase(PmcsPhase.during);
      await pumpPage(tester);

      expect(find.text('TIRES'), findsOneWidget);
      expect(find.text('BRAKES'), findsNothing);
      expect(find.text('Brake Fluid'), findsNothing);
      expect(find.byType(CheckItemCard), findsNWidgets(1));
    });

    testWidgets('opens on the first check owed, with the rest folded away',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(find.text('Reservoir between MIN and MAX'), findsOneWidget);
      expect(find.text('LEVEL OK'), findsOneWidget);
      // The second check is a single row until its turn comes.
      expect(find.text('Parking Brake'), findsOneWidget);
      expect(find.text('Engages and holds'), findsNothing);
      expect(find.text('HOLDS FIRM'), findsNothing);
    });

    testWidgets('an answered check folds away and the next one opens',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'LEVEL OK');

      // Folded: the TM instruction and the options are gone, the verdict stays.
      expect(find.text('Reservoir between MIN and MAX'), findsNothing);
      expect(find.text('LEVEL OK'), findsNothing);
      expect(find.text('OK'), findsOneWidget);
      // The next check owed is in front of the operator, no tap needed.
      expect(find.text('Engages and holds'), findsOneWidget);
      expect(find.text('HOLDS FIRM'), findsOneWidget);
    });

    testWidgets('the answer is written through the moment it is tapped',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'Empty');

      final stored = harness.results.stored['session-1|BEFORE'];
      expect(stored?[brakeFluid.id]?.faultLabel, 'Empty');
    });
  });

  group('closing out the phase', () {
    testWidgets('the complete button is absent until every check is answered',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      expect(completeButton, findsNothing);

      await answer(tester, 'LEVEL OK');
      expect(completeButton, findsNothing);

      await answer(tester, 'HOLDS FIRM');
      expect(
          find.widgetWithText(CustomButton, 'COMPLETE PHASE'), findsOneWidget);
    });

    testWidgets('a phase carrying a RED X says so before it is pressed',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'Reservoir Cracked');
      await answer(tester, 'HOLDS FIRM');

      expect(
        find.widgetWithText(CustomButton, 'COMPLETE WITH RED X'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CustomButton, 'COMPLETE PHASE'), findsNothing);
      expect(find.byIcon(Icons.dangerous_outlined), findsWidgets);
    });

    testWidgets('a deferrable fault does not read as a deadline',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'Low');
      await answer(tester, 'HOLDS FIRM');

      expect(
          find.widgetWithText(CustomButton, 'COMPLETE PHASE'), findsOneWidget);
      expect(
        find.widgetWithText(CustomButton, 'COMPLETE WITH RED X'),
        findsNothing,
      );
    });

    testWidgets(
        'a check answered wrong can be re-answered and the deadline '
        'comes off the button', (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'Reservoir Cracked');
      await answer(tester, 'HOLDS FIRM');
      expect(
        find.widgetWithText(CustomButton, 'COMPLETE WITH RED X'),
        findsOneWidget,
      );

      // Reopen the folded check and correct it.
      await tester.tap(find.text('Brake Fluid'));
      await tester.pumpAndSettle();
      await answer(tester, 'Low');

      expect(
          find.widgetWithText(CustomButton, 'COMPLETE PHASE'), findsOneWidget);
      expect(find.text('RED X: 1'), findsNothing);
      expect(find.text('DASH: 1'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('completing writes the phase faults and returns to the phases',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'Reservoir Cracked');
      await answer(tester, 'HOLDS FIRM');
      await tester
          .tap(find.widgetWithText(CustomButton, 'COMPLETE WITH RED X'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
      expect(
        harness.viewModel.session?.isPhaseComplete(PmcsPhase.before),
        isTrue,
      );
      expect(harness.faults.byPhase['session-1|BEFORE'], hasLength(1));
      expect(harness.viewModel.sessionFaults.single.itemId, brakeFluid.id);
      expect(harness.viewModel.sessionFaults.single.category, 'BRAKES');
    });

    testWidgets('backing out leaves the phase open and the answers on disk',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await pumpPage(tester);

      await answer(tester, 'LEVEL OK');
      await tester.tap(find.byTooltip('Back to phases'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
      expect(
        harness.viewModel.session?.isPhaseComplete(PmcsPhase.before),
        isFalse,
      );
      expect(harness.results.stored['session-1|BEFORE'], hasLength(1));
    });
  });
}
