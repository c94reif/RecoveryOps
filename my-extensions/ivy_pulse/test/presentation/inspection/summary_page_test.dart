import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/summary_page.dart';

import '../../support/cac_fixtures.dart';
import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;

  final deadlining = buildFault(
    itemId: 'B-BRK-01',
    category: 'BRAKES',
    subcategory: 'Brake Fluid',
    condition: 'Reservoir Cracked',
    severity: FaultSeverity.redX,
  );
  final restricting = buildFault(
    itemId: 'B-ENG-01',
    condition: 'Low-Add Oil',
    severity: FaultSeverity.circleX,
  );
  final deferrable = buildFault(
    itemId: 'A-CDN-01',
    phase: PmcsPhase.after,
    category: 'COOL-DOWN',
    subcategory: 'Engine Cool-Down',
    condition: 'Unusual Noise',
    severity: FaultSeverity.dash,
  );

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

  /// A fully walked PMCS carrying [faults], sitting on the summary — the state
  /// the operator is in the moment before they sign the 5988-E.
  Future<void> walkPmcs({List<PmcsFault> faults = const []}) async {
    await harness.sessions.insert(
      buildSession(completedPhases: PmcsPhase.values),
    );
    if (faults.isNotEmpty) {
      await harness.faults.replacePhaseFaults(
        'session-1',
        faults,
        phaseWireName: PmcsPhase.before.wireName,
      );
    }
    await harness.load();
    await harness.viewModel.resumeSession(harness.viewModel.openSessions.first);
    harness.viewModel.openSummary();
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: SummaryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final submitButton = find.widgetWithText(CustomButton, 'SUBMIT PMCS');
  final scanButton = find.widgetWithText(CustomButton, 'SCAN CAC');
  final scanAgainButton = find.widgetWithText(CustomButton, 'SCAN AGAIN');
  final unverifiedButton =
      find.widgetWithText(CustomButton, 'SUBMIT UNVERIFIED');

  testWidgets(
      'coverage distinguishes included, unfinished, and untouched phases',
      (tester) async {
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 0);
    await harness.viewModel.answer(parkingBrake, 0);
    await harness.viewModel.completeActivePhase();
    await harness.viewModel.openPhase(PmcsPhase.during);
    await harness.viewModel.answer(tirePressure, 1);
    harness.viewModel.backToPhases();
    harness.viewModel.openSummary();
    await pumpPage(tester);

    expect(find.text('Before Operations · Complete'), findsOneWidget);
    expect(find.text('During Operations · Unfinished (1 of 1 checks)'),
        findsOneWidget);
    expect(find.text('After Operations · Not started'), findsOneWidget);
    expect(find.text('Only completed phases are included in this report.'),
        findsOneWidget);
  });

  testWidgets(
      'a summary fault opens the matching check with its saved description',
      (tester) async {
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 3);
    await harness.viewModel.saveNote(brakeFluid, 'Crack below reservoir');
    await harness.viewModel.answer(parkingBrake, 0);
    await harness.viewModel.completeActivePhase();
    harness.viewModel.openSummary();
    await pumpPage(tester);

    await tester.tap(find.text('Review check'));
    await tester.pumpAndSettle();
    expect(harness.viewModel.stage, InspectionStage.inspecting);
    expect(harness.viewModel.expandedItemId, brakeFluid.id);
    expect(harness.viewModel.results[brakeFluid.id]!.note,
        'Crack below reservoir');
    expect(harness.viewModel.results[parkingBrake.id]!.isServiceable, isTrue);
  });

  group('the overall status', () {
    testWidgets('reads NMC when a RED X is on the vehicle', (tester) async {
      await walkPmcs(faults: [deferrable, restricting, deadlining]);
      await pumpPage(tester);

      expect(find.text('NMC'), findsOneWidget);
      expect(
        find.textContaining('deadlined until maintenance'),
        findsOneWidget,
      );
      // The banner wears the deadline glyph, never the clean one.
      expect(find.byIcon(Icons.dangerous_outlined), findsWidgets);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
    });

    testWidgets('reads FMC when the PMCS came back clean', (tester) async {
      await walkPmcs();
      await pumpPage(tester);

      expect(find.text('FMC'), findsOneWidget);
      expect(find.textContaining('no deficiencies found'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      expect(find.text('No faults recorded'), findsOneWidget);
      expect(find.byType(FaultTallyBar), findsNothing);
    });

    testWidgets('a CIRCLE X restricts the vehicle rather than deadlining it',
        (tester) async {
      await walkPmcs(faults: [restricting]);
      await pumpPage(tester);

      expect(find.text('LIMITED'), findsOneWidget);
      expect(find.textContaining('commander approval'), findsOneWidget);
      expect(find.text('NMC'), findsNothing);
    });

    testWidgets('deferrable faults still leave the vehicle mission capable',
        (tester) async {
      await walkPmcs(faults: [deferrable]);
      await pumpPage(tester);

      expect(find.text('FMC (DASH)'), findsOneWidget);
      expect(
          find.textContaining('deferrable deficiencies noted'), findsOneWidget);
      expect(find.text('NMC'), findsNothing);
      expect(find.text('LIMITED'), findsNothing);
    });

    testWidgets('the header names the vehicle and the UIC', (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.text('WJ8TAA'), findsOneWidget);
    });

    testWidgets('shows nothing at all when there is no walk-around to sign',
        (tester) async {
      await harness.load();
      await pumpPage(tester);

      expect(submitButton, findsNothing);
      expect(find.text('FMC'), findsNothing);
    });
  });

  group('the fault list', () {
    testWidgets('groups the faults by symbol and counts each group',
        (tester) async {
      await walkPmcs(faults: [deferrable, restricting, deadlining]);
      await pumpPage(tester);

      expect(find.text('RED X — 1'), findsOneWidget);
      expect(find.text('CIRCLE X — 1'), findsOneWidget);
      expect(find.text('DASH — 1'), findsOneWidget);
      expect(find.byType(SeverityBadge), findsNWidgets(6));
    });

    testWidgets(
        'puts the deadlining faults first, whatever order they '
        'were found in', (tester) async {
      // Stored worst-last on purpose: the walk-around order must not decide
      // what the maintainer reads first.
      await walkPmcs(faults: [deferrable, restricting, deadlining]);
      await pumpPage(tester);

      final redXAt = tester.getTopLeft(find.text('RED X — 1')).dy;
      final circleXAt = tester.getTopLeft(find.text('CIRCLE X — 1')).dy;
      final dashAt = tester.getTopLeft(find.text('DASH — 1')).dy;

      expect(redXAt, lessThan(circleXAt));
      expect(circleXAt, lessThan(dashAt));
      expect(
        tester.getTopLeft(find.text('Brake Fluid')).dy,
        lessThan(tester.getTopLeft(find.text('Engine Oil Level')).dy),
      );
    });

    testWidgets('a group with several faults counts all of them',
        (tester) async {
      await walkPmcs(
        faults: [
          deadlining,
          deadlining.copyWith(),
          restricting,
        ],
      );
      await pumpPage(tester);

      expect(find.text('RED X — 2'), findsOneWidget);
      expect(find.text('CIRCLE X — 1'), findsOneWidget);
      expect(find.text('DASH — 1'), findsNothing);
    });

    testWidgets(
        'each fault carries its TM id, station, component, phase and '
        'condition', (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      expect(find.text('B-BRK-01'), findsOneWidget);
      expect(find.text('Brake Fluid'), findsOneWidget);
      expect(find.text('BRAKES · BEFORE'), findsOneWidget);
      expect(find.text('Reservoir Cracked'), findsOneWidget);
      expect(find.byIcon(severityIcon(FaultSeverity.redX)), findsWidgets);
    });

    testWidgets('the note the operator dictated rides along', (tester) async {
      await walkPmcs(
        faults: [
          deadlining.copyWith(note: 'reservoir bone dry, fluid on the hub'),
        ],
      );
      await pumpPage(tester);

      expect(
        find.text('reservoir bone dry, fluid on the hub'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });

    testWidgets('a fault with no note carries no empty note row',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });

    testWidgets('the tally bar counts everything found on the vehicle',
        (tester) async {
      await walkPmcs(faults: [deferrable, restricting, deadlining]);
      await pumpPage(tester);

      expect(find.text('3 FAULTS'), findsOneWidget);
      expect(find.text('RED X: 1'), findsOneWidget);
      expect(find.text('CIRCLE X: 1'), findsOneWidget);
      expect(find.text('DASH: 1'), findsOneWidget);
    });
  });

  /// Scans a readable CAC through the sign-off card, which is the only way
  /// SUBMIT PMCS ever appears.
  Future<void> signOff(WidgetTester tester) async {
    harness.cacScanner.willRead(cacBarcode());
    await tester.tap(scanButton);
    await tester.pumpAndSettle();
  }

  group('signing off', () {
    testWidgets('the summary opens asking for a CAC, not for a submit',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      expect(find.text('SIGN OFF'), findsOneWidget);
      expect(scanButton, findsOneWidget);
      expect(submitButton, findsNothing);
      expect(unverifiedButton, findsNothing);
    });

    testWidgets('a read CAC names the Soldier and unlocks the submit',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      await signOff(tester);

      expect(find.text('SGT SMITH, JOHN A'), findsOneWidget);
      expect(find.textContaining('DoD ID 1087987498'), findsOneWidget);
      expect(find.textContaining('US Army'), findsOneWidget);
      expect(submitButton, findsOneWidget);
      expect(tester.widget<CustomButton>(submitButton).onPressed, isNotNull);
    });

    testWidgets('a refused scan says why and offers the override',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      harness.cacScanner.willFail(CacRejection.noCamera);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No camera available on this device'),
        findsOneWidget,
      );
      // A device with no camera returns the identical answer however the card
      // is held, so the override takes the primary button and SCAN AGAIN
      // demotes to a link — demoted, never removed.
      expect(unverifiedButton, findsOneWidget);
      expect(scanAgainButton, findsNothing);
      expect(find.widgetWithText(TextButton, 'SCAN AGAIN'), findsOneWidget);
      expect(submitButton, findsNothing);
    });

    testWidgets('a card that is not a CAC is refused with an instruction',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      harness.cacScanner.willRead('not a cac at all');
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not a CAC'),
        findsOneWidget,
      );
      expect(submitButton, findsNothing);
    });

    testWidgets('the override will not send without a confirmation',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      harness.cacScanner.willFail(CacRejection.noCamera);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      await tester.tap(unverifiedButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.reports.reports, isEmpty);
      expect(harness.viewModel.stage, InspectionStage.summary);
    });

    testWidgets('a confirmed override sends the PMCS marked unverified',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      harness.cacScanner.willFail(CacRejection.noCamera);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      await tester.tap(unverifiedButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Unverified'));
      await tester.pumpAndSettle();

      final report = harness.reports.reports.single;
      expect(report.isSignatureVerified, isFalse);
      expect(report.signature!.blockedBy, CacRejection.noCamera);
      expect(harness.viewModel.stage, InspectionStage.submitted);
    });

    testWidgets('RESCAN throws the first read away', (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      await signOff(tester);

      await tester.tap(find.text('NOT ME — RESCAN'));
      await tester.pumpAndSettle();

      expect(harness.cacScanner.captureCalls, 2);
    });
  });

  group('submitting', () {
    testWidgets('SUBMIT PMCS is offered and live once the CAC is read',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      await signOff(tester);

      expect(submitButton, findsOneWidget);
      expect(tester.widget<CustomButton>(submitButton).onPressed, isNotNull);
    });

    testWidgets('submitting stores the report and clears the walk-around',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      await signOff(tester);

      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(harness.reports.reports, hasLength(1));
      expect(harness.reports.reports.single.bumperNumber, 'A-11');
      expect(harness.reports.reports.single.statusLabel, 'NMC');
      expect(harness.reports.reports.single.operator, 'SGT SMITH, JOHN A');
      expect(harness.reports.reports.single.isSignatureVerified, isTrue);
      expect(harness.viewModel.session, isNull);
      expect(harness.viewModel.stage, InspectionStage.submitted);
    });

    testWidgets('the report goes out on Lattice and the mesh together',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      await signOff(tester);

      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(harness.entityPort.published, hasLength(1));
      expect(harness.meshPort.broadcast, hasLength(1));
    });

    testWidgets(
        'a downed transport parks the report on the queue instead of '
        'losing it', (tester) async {
      harness.entityPort.publishSucceeds = false;
      harness.meshPort.broadcastSucceeds = false;
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);
      await signOff(tester);

      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Stored locally first, so the PMCS is never lost with the net.
      expect(harness.reports.reports, hasLength(1));
      expect(harness.queueWorker.enqueued, hasLength(2));
      expect(harness.viewModel.stage, InspectionStage.submitted);
    });

    testWidgets('back to phases leaves the walk-around unsubmitted',
        (tester) async {
      await walkPmcs(faults: [deadlining]);
      await pumpPage(tester);

      await tester.tap(find.text('BACK TO PHASES'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
      expect(harness.viewModel.session?.sessionId, 'session-1');
      expect(harness.reports.reports, isEmpty);
    });
  });
}
