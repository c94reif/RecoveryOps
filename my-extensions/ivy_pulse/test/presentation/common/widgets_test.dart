import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/phase_progress_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/quick_pick_chips.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';

Widget host(Widget child) => MaterialApp(
      theme: appTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('SeverityBadge', () {
    for (final severity in FaultSeverity.values) {
      testWidgets(
          'a ${severity.label} badge carries a glyph and a label, '
          'never colour alone', (tester) async {
        await tester.pumpWidget(host(SeverityBadge(severity: severity)));

        expect(find.text(severity.label), findsOneWidget);
        expect(find.byIcon(severityIcon(severity)), findsOneWidget);
      });

      testWidgets('a ${severity.label} badge shows how many were found',
          (tester) async {
        await tester
            .pumpWidget(host(SeverityBadge(severity: severity, count: 3)));

        expect(find.text('${severity.label}: 3'), findsOneWidget);
        expect(find.byIcon(severityIcon(severity)), findsOneWidget);
      });
    }

    testWidgets('each severity uses a glyph of its own', (tester) async {
      final glyphs = FaultSeverity.values.map(severityIcon).toSet();

      expect(glyphs, hasLength(FaultSeverity.values.length));
    });
  });

  group('FaultTallyBar', () {
    testWidgets('a clean vehicle renders nothing at all', (tester) async {
      await tester.pumpWidget(host(const FaultTallyBar(tally: FaultTally())));

      expect(find.byType(SeverityBadge), findsNothing);
      expect(find.textContaining('FAULT'), findsNothing);
      expect(tester.getSize(find.byType(FaultTallyBar)), Size.zero);
    });

    testWidgets('severities with no faults get no badge', (tester) async {
      await tester.pumpWidget(host(
        const FaultTallyBar(tally: FaultTally(redX: 1, circleX: 0, dash: 2)),
      ));

      expect(find.text('3 FAULTS'), findsOneWidget);
      expect(find.text('RED X: 1'), findsOneWidget);
      expect(find.text('DASH: 2'), findsOneWidget);
      expect(find.textContaining('CIRCLE X'), findsNothing);
      expect(find.byType(SeverityBadge), findsNWidgets(2));
    });

    testWidgets('a single fault reads FAULT, not FAULTS', (tester) async {
      await tester.pumpWidget(
        host(const FaultTallyBar(tally: FaultTally(dash: 1))),
      );

      expect(find.text('1 FAULT'), findsOneWidget);
    });

    testWidgets('badges run worst symbol first', (tester) async {
      await tester.pumpWidget(host(
        const FaultTallyBar(tally: FaultTally(redX: 1, circleX: 1, dash: 1)),
      ));

      final labels = tester
          .widgetList<SeverityBadge>(find.byType(SeverityBadge))
          .map((badge) => badge.severity)
          .toList();

      expect(labels, [
        FaultSeverity.redX,
        FaultSeverity.circleX,
        FaultSeverity.dash,
      ]);
    });
  });

  group('PhaseProgressBar', () {
    testWidgets('shows how many checks of the phase are answered',
        (tester) async {
      await tester.pumpWidget(host(const PhaseProgressBar(done: 4, total: 12)));

      expect(find.text('4 / 12'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(4 / 12, 0.0001),
      );
    });

    testWidgets('a phase with no checks does not divide by zero',
        (tester) async {
      await tester.pumpWidget(host(const PhaseProgressBar(done: 0, total: 0)));

      expect(find.text('0 / 0'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0.0,
      );
    });

    testWidgets('a part-walked phase does not read as a finished one',
        (tester) async {
      await tester
          .pumpWidget(host(const PhaseProgressBar(done: 11, total: 12)));

      final partial = tester.widget<Text>(find.text('11 / 12')).style!.color;

      await tester
          .pumpWidget(host(const PhaseProgressBar(done: 12, total: 12)));

      final complete = tester.widget<Text>(find.text('12 / 12')).style!.color;

      expect(complete, serviceableGreen);
      expect(partial, isNot(serviceableGreen));
    });
  });

  group('QuickPickChips', () {
    testWidgets('tapping an option calls back with that option',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(host(QuickPickChips(
        options: const ['SGT', 'SSG', 'SFC'],
        onSelected: picked.add,
      )));

      await tester.tap(find.text('SSG'));
      await tester.pump();

      expect(picked, ['SSG']);
    });

    testWidgets('no option is announced until one is tapped', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(host(QuickPickChips(
        options: const ['SGT', 'SSG'],
        onSelected: picked.add,
      )));

      expect(picked, isEmpty);
    });

    testWidgets('every chip clears the gloved-thumb touch target',
        (tester) async {
      await tester.pumpWidget(host(QuickPickChips(
        options: const ['SGT', 'SSG', 'SFC'],
        onSelected: (_) {},
      )));

      final chips = find.byType(GestureDetector);
      expect(chips, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(
          tester.getSize(chips.at(i)).height,
          greaterThanOrEqualTo(minTouchTarget),
        );
      }
    });
  });

  group('CustomButton', () {
    testWidgets('a null callback disables the button', (tester) async {
      await tester.pumpWidget(
        host(const CustomButton(text: 'BEGIN PMCS', onPressed: null)),
      );

      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
        isFalse,
      );
    });

    testWidgets('a disabled button swallows a tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(Column(children: [
        const CustomButton(text: 'BEGIN PMCS', onPressed: null),
        CustomButton(text: 'SUBMIT', onPressed: () => taps++),
      ])));

      await tester.tap(find.text('BEGIN PMCS'));
      await tester.pump();
      expect(taps, 0);

      await tester.tap(find.text('SUBMIT'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the button clears the gloved-thumb touch target',
        (tester) async {
      await tester.pumpWidget(
        host(CustomButton(text: 'SUBMIT', onPressed: () {})),
      );

      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(minTouchTarget),
      );
    });
  });

  group('showConfirmDialog', () {
    late List<bool> answers;

    Widget dialogHost() {
      return MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answers.add(await showConfirmDialog(
                  context,
                  title: 'Delete PMCS?',
                  message: 'A-11 will be withdrawn from Lattice and the mesh.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    setUp(() => answers = []);

    testWidgets('confirming resolves true', (tester) async {
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete PMCS?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(answers, [true]);
    });

    testWidgets('cancelling resolves false', (tester) async {
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });

    testWidgets('dismissing the dialog counts as a refusal', (tester) async {
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });

    testWidgets('both answers clear the gloved-thumb touch target',
        (tester) async {
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final label in ['Cancel', 'Delete']) {
        expect(
          tester.getSize(find.widgetWithText(TextButton, label)).height,
          greaterThanOrEqualTo(minTouchTarget),
        );
      }
    });
  });
}
