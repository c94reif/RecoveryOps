import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/maintainer/swipe_fault_card.dart';
import '../../support/fakes.dart';

void main() {
  Widget subject(ValueChanged<bool> onDecision,
          {bool enabled = true, bool reducedMotion = false}) =>
      MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                  width: 360,
                  child: SwipeFaultCard(
                      fault: buildFault(),
                      decision: null,
                      hasNext: true,
                      enabled: enabled,
                      onDecision: onDecision)),
            ),
          ),
        ),
      );
  final swipe = find.byKey(const ValueKey('fault-swipe-area'));
  final motion = find.byKey(const ValueKey('fault-card-motion'));

  testWidgets('short swipes show a stamp then return without deciding',
      (tester) async {
    final decisions = <bool>[];
    await tester.pumpWidget(subject(decisions.add));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(swipe));
    await gesture.moveBy(const Offset(55, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(
        tester.widget<Transform>(motion).transform.storage[12], greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(decisions, isEmpty);
    expect(find.text('VERIFIED'), findsNothing);
    expect(tester.widget<Transform>(motion).transform.storage[12], 0);
  });

  for (final verified in [true, false]) {
    testWidgets(
        'a ${verified ? 'right' : 'left'} swipe decides once after flying out',
        (tester) async {
      final decisions = <bool>[];
      await tester.pumpWidget(subject(decisions.add));
      await tester.pumpAndSettle();
      await tester.drag(swipe, Offset(verified ? 180 : -180, 0));
      expect(decisions, isEmpty);
      await tester.pump(const Duration(milliseconds: 120));
      expect(decisions, isEmpty);
      await tester.pumpAndSettle();
      expect(decisions, [verified]);
      expect(tester.widget<Transform>(motion).transform.storage[12], 0);
    });
  }

  testWidgets(
      'rapid button taps animate one decision and disabling cancels a pending swipe',
      (tester) async {
    final decisions = <bool>[];
    await tester.pumpWidget(subject(decisions.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified'));
    await tester.tap(find.text('Not verified'));
    await tester.pumpAndSettle();
    expect(decisions, [true]);
    await tester.drag(swipe, const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(subject(decisions.add, enabled: false));
    await tester.pumpAndSettle();
    expect(decisions, [true]);
    expect(tester.widget<Transform>(motion).transform.storage[12], 0);
  });

  testWidgets('leaving during the fly-out never applies a late decision',
      (tester) async {
    final decisions = <bool>[];
    await tester.pumpWidget(subject(decisions.add));
    await tester.pumpAndSettle();
    await tester.drag(swipe, const Offset(180, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(decisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps decisions available without a fly-out',
      (tester) async {
    final decisions = <bool>[];
    await tester.pumpWidget(subject(decisions.add, reducedMotion: true));
    await tester.pump();
    await tester.tap(find.text('Verified'));
    expect(decisions, [true]);
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(motion).transform.storage[12], 0);
  });
}
