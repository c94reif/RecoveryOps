import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/setup_page.dart';

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

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: appTheme,
      home: const Scaffold(body: SetupPage()),
    );
  }

  Finder field(String label) => find.widgetWithText(CustomTextField, label);

  final beginButton = find.widgetWithText(CustomButton, 'BEGIN PMCS');

  bool isBeginEnabled(WidgetTester tester) =>
      tester.widget<CustomButton>(beginButton).onPressed != null;

  group('starting a PMCS', () {
    testWidgets('BEGIN PMCS stays dead until a bumper number and a UIC are in',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(beginButton, findsOneWidget);
      expect(isBeginEnabled(tester), isFalse);

      await tester.enterText(field('Bumper Number'), 'HQ-9');
      await tester.pump();
      expect(isBeginEnabled(tester), isFalse);

      await tester.enterText(field('UIC'), 'WAB4C0');
      await tester.pump();
      expect(isBeginEnabled(tester), isTrue);
    });

    testWidgets('a UIC on its own is not enough either', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(field('UIC'), 'WAB4C0');
      await tester.pump();

      expect(isBeginEnabled(tester), isFalse);
    });

    testWidgets('whitespace does not count as a filled field', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(field('Bumper Number'), '   ');
      await tester.enterText(field('UIC'), '   ');
      await tester.pump();

      expect(isBeginEnabled(tester), isFalse);
    });

    testWidgets('a vehicle handed over from a report card lands in the fields',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      harness.viewModel.prefillVehicle(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: VehicleType.jltv,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<CustomTextField>(field('Bumper Number')).controller.text,
        'B-22',
      );
      expect(
        tester.widget<CustomTextField>(field('UIC')).controller.text,
        'WAB4C0',
      );
      expect(harness.viewModel.selectedVehicle, VehicleType.jltv);
      // Consumed on arrival, so a later rebuild cannot put it back over an
      // edit the operator has since made.
      expect(harness.viewModel.pendingPrefill, isNull);
    });

    testWidgets('the UIC the operator is signed for arrives with the profile',
        (tester) async {
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      final uicField = tester.widget<CustomTextField>(field('UIC'));
      expect(uicField.controller.text, 'WJ8TAA');

      // Still one field short: the bumper number is never guessed.
      expect(isBeginEnabled(tester), isFalse);

      await tester.enterText(field('Bumper Number'), 'HQ-9');
      await tester.pump();
      expect(isBeginEnabled(tester), isTrue);
    });

    testWidgets('a borrowed vehicle can be walked under another UIC',
        (tester) async {
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(field('UIC'), 'wab4c0');
      await tester.enterText(field('Bumper Number'), 'C-13');
      await tester.pump();
      await tester.tap(beginButton);
      await tester.pumpAndSettle();

      expect(harness.viewModel.session?.uic, 'WAB4C0');
    });

    testWidgets('beginning moves on to the phases with nobody signed to it',
        (tester) async {
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(field('Bumper Number'), 'HQ-9');
      await tester.pump();
      await tester.tap(beginButton);
      await tester.pumpAndSettle();

      expect(harness.viewModel.session?.bumperNumber, 'HQ-9');
      // The CAC scan at submit is what names the operator.
      expect(harness.viewModel.session?.operator, '');
      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
    });
  });

  group('the vehicle platform selector', () {
    testWidgets('lists every supported platform with the TM it came from',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Stryker'), findsOneWidget);
      expect(find.text('TM 9-2355-311-10'), findsOneWidget);
      expect(find.text('JLTV'), findsOneWidget);
      expect(find.text('TM 9-2320-400-10'), findsOneWidget);
    });

    testWidgets('opens on the first platform the build carries',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final selector = tester.widget<SegmentedButton<VehicleType>>(
        find.byType(SegmentedButton<VehicleType>),
      );
      expect(selector.selected, {VehicleType.stryker});
    });

    testWidgets('picking a platform switches the checklist that gets walked',
        (tester) async {
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('JLTV'));
      await tester.pump();

      final selector = tester.widget<SegmentedButton<VehicleType>>(
        find.byType(SegmentedButton<VehicleType>),
      );
      expect(selector.selected, {VehicleType.jltv});

      await tester.enterText(field('Bumper Number'), 'HQ-9');
      await tester.pump();
      await tester.tap(beginButton);
      await tester.pumpAndSettle();

      expect(harness.viewModel.session?.vehicleType, VehicleType.jltv);
      expect(harness.viewModel.catalog?.vehicleType, VehicleType.jltv);
    });
  });

  group('resuming an open PMCS', () {
    testWidgets('nothing is offered for resume when nothing is open',
        (tester) async {
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('RESUME PMCS'), findsNothing);
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('an open PMCS is offered with its bumper number and its UIC',
        (tester) async {
      await harness.sessions.insert(buildSession());
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('RESUME PMCS'), findsOneWidget);
      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('WJ8TAA'),
        ),
        findsOneWidget,
      );
      expect(find.text('3 phase(s) remaining'), findsOneWidget);
    });

    testWidgets('the phases already closed out are marked off', (tester) async {
      await harness.sessions.insert(
        buildSession(completedPhases: const [PmcsPhase.before]),
      );
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('DURING'), findsOneWidget);
      expect(find.text('AFTER'), findsOneWidget);
      // Only the finished phase carries the tick.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('2 phase(s) remaining'), findsOneWidget);
    });

    testWidgets('every open PMCS gets its own card', (tester) async {
      await harness.sessions.insert(buildSession(sessionId: 'open-1'));
      await harness.sessions.insert(
        buildSession(sessionId: 'open-2', bumperNumber: 'B-24'),
      );
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byIcon(Icons.history), findsNWidgets(2));
      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.text('B-24 - Stryker'), findsOneWidget);
    });

    testWidgets('tapping one picks the walk-around back up where it stopped',
        (tester) async {
      await harness.sessions.insert(
        buildSession(completedPhases: const [PmcsPhase.before]),
      );
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('A-11 - Stryker'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.stage, InspectionStage.phaseSelect);
      expect(harness.viewModel.session?.sessionId, 'session-1');
      expect(harness.viewModel.catalog?.vehicleType, VehicleType.stryker);
      expect(
        harness.viewModel.session?.isPhaseComplete(PmcsPhase.before),
        isTrue,
      );
    });

    testWidgets('a resumed PMCS brings the faults already found with it',
        (tester) async {
      await harness.sessions.insert(
        buildSession(completedPhases: const [PmcsPhase.before]),
      );
      await harness.faults.replacePhaseFaults(
        'session-1',
        [buildFault()],
        phaseWireName: PmcsPhase.before.wireName,
      );
      await harness.load();
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('A-11 - Stryker'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.sessionFaults, hasLength(1));
    });
  });
}
