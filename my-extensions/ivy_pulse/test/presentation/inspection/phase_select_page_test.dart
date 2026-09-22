import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/phase_select_page.dart';

import '../../support/fakes.dart';
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

  /// The EUD is taller than the default test surface, and every phase card has
  /// to be tappable without the test scrolling for it.
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: PhaseSelectPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Picks a stored walk-around back up, so a phase can already be closed out
  /// before the page is ever built.
  Future<void> resumeWith(List<PmcsPhase> completedPhases) async {
    await harness.sessions.insert(
      buildSession(completedPhases: completedPhases),
    );
    await harness.load();
    await harness.viewModel.resumeSession(harness.viewModel.openSessions.first);
  }

  final summaryButton = find.widgetWithText(CustomButton, 'VIEW PMCS SUMMARY');

  group('the phase list', () {
    testWidgets('shows nothing at all until a walk-around is open',
        (tester) async {
      await harness.load();
      await pumpPage(tester);

      expect(find.text('SELECT PHASE'), findsNothing);
      expect(find.text('Before Operations'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('names the vehicle, the UIC and the TM being walked',
        (tester) async {
      await harness.begin();
      await pumpPage(tester);

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.text('WJ8TAA · TM 9-2355-311-10'), findsOneWidget);
    });

    testWidgets('gives every TM phase a card of its own', (tester) async {
      await harness.begin();
      await pumpPage(tester);

      expect(find.text('Before Operations'), findsOneWidget);
      expect(find.text('During Operations'), findsOneWidget);
      expect(find.text('After Operations'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(PmcsPhase.values.length));
    });

    testWidgets('each card carries the number of checks that phase owes',
        (tester) async {
      await harness.begin();
      await pumpPage(tester);

      // BEFORE carries both brake checks; DURING and AFTER carry one each.
      expect(find.text('2 checks'), findsOneWidget);
      expect(find.text('1 check'), findsNWidgets(2));
      expect(find.text('NOT STARTED'), findsNWidgets(3));
    });

    testWidgets('a phase the catalog has nothing for reads as zero checks',
        (tester) async {
      // The JLTV catalog only carries BEFORE, so the other two are empty.
      harness.viewModel.selectVehicle(VehicleType.jltv);
      await harness.begin();
      await pumpPage(tester);

      expect(find.text('1 check'), findsOneWidget);
      expect(find.text('0 checks'), findsNWidgets(2));
    });

    testWidgets('tapping a phase opens it for inspection', (tester) async {
      await harness.begin();
      await pumpPage(tester);

      await tester.tap(find.text('During Operations'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.inspecting);
      expect(harness.viewModel.activePhase, PmcsPhase.during);
      expect(harness.viewModel.totalCount, 1);
    });
  });

  group('saved phase progress', () {
    testWidgets('returning to phases shows answers without closing the phase',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await harness.viewModel.answer(brakeFluid, 1);
      harness.viewModel.backToPhases();
      await pumpPage(tester);

      expect(find.text('1 of 2 complete'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('NOT STARTED'), findsNWidgets(2));

      await harness.viewModel.openPhase(PmcsPhase.before);
      await harness.viewModel.answer(parkingBrake, 0);
      harness.viewModel.backToPhases();
      await tester.pumpAndSettle();

      expect(find.text('2 of 2 complete'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('COMPLETE'), findsNothing);

      await harness.viewModel.openPhase(PmcsPhase.before);
      await harness.viewModel.completeActivePhase();
      await tester.pumpAndSettle();

      expect(find.text('2 of 2 complete'), findsOneWidget);
      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsNothing);
    });

    testWidgets('resuming restores progress across multiple unfinished phases',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await harness.viewModel.answer(brakeFluid, 0);
      await harness.viewModel.openPhase(PmcsPhase.during);
      await harness.viewModel.answer(tirePressure, 1);
      final session = harness.viewModel.session!;
      await harness.viewModel.resetToSetup();
      await harness.viewModel.resumeSession(session);
      await pumpPage(tester);

      expect(find.text('1 of 2 complete'), findsOneWidget);
      expect(find.text('1 of 1 complete'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsNWidgets(2));
      expect(find.text('NOT STARTED'), findsOneWidget);
    });

    testWidgets('discarding a session clears progress for the next vehicle',
        (tester) async {
      await harness.beginPhase(PmcsPhase.before);
      await harness.viewModel.answer(brakeFluid, 0);
      await harness.viewModel.discardSession();
      await harness.viewModel.beginSession(bumperNumber: 'B-22', uic: 'WAB4C0');
      await pumpPage(tester);

      expect(find.text('NOT STARTED'), findsNWidgets(3));
      expect(find.text('IN PROGRESS'), findsNothing);
      expect(find.text('2 checks'), findsOneWidget);
    });
  });

  group('a phase already closed out', () {
    testWidgets('is marked complete and the others are not', (tester) async {
      await resumeWith(const [PmcsPhase.before]);
      await pumpPage(tester);

      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // The two phases still owed keep their chevron.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('every phase is marked once the whole PMCS is walked',
        (tester) async {
      await resumeWith(PmcsPhase.values);
      await pumpPage(tester);

      expect(find.text('COMPLETE'), findsNWidgets(PmcsPhase.values.length));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('stays open so the operator can re-read what they signed for',
        (tester) async {
      await resumeWith(const [PmcsPhase.before]);
      await pumpPage(tester);

      await tester.tap(find.text('Before Operations'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.inspecting);
      expect(harness.viewModel.activePhase, PmcsPhase.before);
    });

    testWidgets('reopens with the answers already recorded on it',
        (tester) async {
      await harness.results.upsertResult(
        'session-1',
        PmcsPhase.before,
        CheckResult(
          itemId: brakeFluid.id,
          faultIndex: 1,
          faultLabel: 'Low',
          severity: FaultSeverity.dash,
          recordedAt: DateTime.utc(2026, 3, 24, 7),
        ),
      );
      await resumeWith(const [PmcsPhase.before]);
      await pumpPage(tester);

      await tester.tap(find.text('Before Operations'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.answeredCount, 1);
      expect(harness.viewModel.results[brakeFluid.id]?.faultLabel, 'Low');
    });
  });

  group('the RED X badge', () {
    void deadline(PmcsPhase phase) {
      harness.faults.byPhase['session-1|${phase.wireName}'] = [
        buildFault(severity: FaultSeverity.redX, phase: phase),
      ];
    }

    testWidgets('marks the phase holding a RED X, and only that phase',
        (tester) async {
      deadline(PmcsPhase.before);
      await resumeWith([]);
      await pumpPage(tester);

      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('a CIRCLE X does not earn it — the vehicle can still roll',
        (tester) async {
      harness.faults.byPhase['session-1|${PmcsPhase.before.wireName}'] = [
        buildFault(severity: FaultSeverity.circleX, phase: PmcsPhase.before),
      ];
      await resumeWith([]);
      await pumpPage(tester);

      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('stays on the card once the phase is closed out',
        (tester) async {
      deadline(PmcsPhase.after);
      await resumeWith([PmcsPhase.after]);
      await pumpPage(tester);

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('COMPLETE'), findsOneWidget);
    });
  });

  group('the summary button', () {
    testWidgets('is not offered before a single phase is done', (tester) async {
      await harness.begin();
      await pumpPage(tester);

      expect(summaryButton, findsNothing);
    });

    testWidgets('appears as soon as one phase is closed out', (tester) async {
      await resumeWith(const [PmcsPhase.before]);
      await pumpPage(tester);

      expect(summaryButton, findsOneWidget);
    });

    testWidgets('opens the summary when tapped', (tester) async {
      await resumeWith(const [PmcsPhase.before]);
      await pumpPage(tester);

      await tester.tap(summaryButton);
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.summary);
    });
  });

  group('discarding a walk-around', () {
    testWidgets('asks first, naming the vehicle that would be wiped',
        (tester) async {
      await harness.begin();
      await pumpPage(tester);

      await tester.tap(find.text('Discard session'));
      await tester.pumpAndSettle();

      expect(find.text('Discard PMCS?'), findsOneWidget);
      expect(find.textContaining('A-11'), findsWidgets);
    });

    testWidgets('backing out of the dialog keeps the walk-around',
        (tester) async {
      await harness.begin();
      await pumpPage(tester);

      await tester.tap(find.text('Discard session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.session?.sessionId, 'session-1');
      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
      expect(harness.sessions.deleted, isEmpty);
    });

    testWidgets('confirming wipes the session and returns to setup',
        (tester) async {
      await harness.begin();
      await pumpPage(tester);

      await tester.tap(find.text('Discard session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISCARD'));
      await tester.pumpAndSettle();

      expect(harness.sessions.deleted, ['session-1']);
      expect(harness.viewModel.session, isNull);
      expect(harness.viewModel.stage, InspectionStage.setup);
    });
  });
}
