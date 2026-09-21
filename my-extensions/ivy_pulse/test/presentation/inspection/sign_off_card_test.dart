import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off_card.dart';
import 'package:ivy_pulse/presentation/inspection/summary_page.dart';

import '../../support/cac_fixtures.dart';
import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

/// The sign-off card at the size the host actually gives the extension.
///
/// Everything here is driven through the real [SummaryPage] rather than the
/// card alone, because the risk the aim diagram introduced is a layout one:
/// a drawing that pushes SCAN AGAIN and SUBMIT UNVERIFIED below the fold at
/// the exact moment the Soldier needs them. A card pumped on its own in an
/// unbounded box would never show that.
void main() {
  /// Measured on a device the panel is roughly 470x420 logical pixels once the
  /// host's own title bar is out; this holds it to a stricter 370x314 so a 5"
  /// phone is covered too. Same reasoning as `pmcs_flow_smoke_test`.
  const panel = Size(370, 314);

  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
  });

  tearDown(() async {
    await getIt.reset();
    clearSnackBars();
  });

  /// A walked PMCS sitting on the summary, signed by nobody yet.
  Future<void> walkPmcs({HangingCacScanner? scanner}) async {
    harness = InspectionHarness(scanner: scanner);
    harness.register();
    await harness.sessions.insert(
      buildSession(completedPhases: PmcsPhase.values),
    );
    await harness.load();
    await harness.viewModel.resumeSession(harness.viewModel.openSessions.first);
    harness.viewModel.openSummary();
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = panel;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SizedBox(
            width: panel.width,
            height: panel.height,
            child: const SummaryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final scanButton = find.widgetWithText(CustomButton, 'SCAN CAC');
  final scanAgainButton = find.widgetWithText(CustomButton, 'SCAN AGAIN');
  final scanAgainLink = find.widgetWithText(TextButton, 'SCAN AGAIN');
  final overrideButton = find.widgetWithText(CustomButton, 'SUBMIT UNVERIFIED');
  final overrideLink = find.widgetWithText(TextButton, 'SUBMIT UNVERIFIED');

  /// The summary is a ListView on a 314px panel, so anything below the fold is
  /// reached the way the operator reaches it.
  Future<void> reach(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAfterScrolling(WidgetTester tester, Finder target) async {
    await reach(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Scans and lands on whatever the fake was told to hand back.
  Future<void> scan(WidgetTester tester, {Finder? from}) =>
      tapAfterScrolling(tester, from ?? scanButton);

  group('the scanning state', () {
    // This state used to render no controls at all. With a capture timeout of
    // two minutes behind it, that is two minutes of spinner with no way out —
    // and before the timeout existed it was the rest of the session.
    testWidgets('offers a cancel control while the camera is open',
        (tester) async {
      final scanner = HangingCacScanner();
      await walkPmcs(scanner: scanner);
      await pumpPanel(tester);

      await reach(tester, scanButton);
      await tester.tap(scanButton);
      // Never pumpAndSettle here: the scanning card holds a
      // CircularProgressIndicator and settling waits on an animation that
      // does not end.
      await tester.pump();

      expect(harness.viewModel.isScanning, isTrue);
      expect(find.text('CANCEL SCAN'), findsOneWidget);
    });

    testWidgets('says honestly what cancelling can and cannot do',
        (tester) async {
      final scanner = HangingCacScanner();
      await walkPmcs(scanner: scanner);
      await pumpPanel(tester);
      await reach(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pump();

      expect(
          find.textContaining('cannot close the camera app'), findsOneWidget);
    });

    testWidgets('names the landmarks rather than "the front"', (tester) async {
      final scanner = HangingCacScanner();
      await walkPmcs(scanner: scanner);
      await pumpPanel(tester);
      await reach(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pump();

      expect(find.textContaining('photo and the gold chip'), findsOneWidget);
      expect(find.textContaining('front of the CAC'), findsNothing);
    });

    testWidgets('the cancel control is reachable and ends the scan',
        (tester) async {
      final scanner = HangingCacScanner();
      await walkPmcs(scanner: scanner);
      await pumpPanel(tester);
      await reach(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('CANCEL SCAN'),
        find.byType(Scrollable).first,
        const Offset(0, -80),
      );
      await tester.pump();
      await tester.tap(find.text('CANCEL SCAN'));
      await tester.pumpAndSettle();

      expect(harness.viewModel.isScanning, isFalse);
      expect(scanner.cancelCalls, 1);
      // Lands on the refused card, which has the two things the operator can
      // still do on it.
      expect(find.text('Scan cancelled.'), findsOneWidget);
      expect(scanAgainButton, findsOneWidget);
      expect(overrideLink, findsOneWidget);
    });
  });

  group('the aim guide', () {
    /// The schematic's own box, found by the width the card declares.
    Finder schematic() => find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == SignOffCard.cardWidth,
        );

    testWidgets('sits in the prompt, unasked and untoggled', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);

      // No disclosure, no auto-expand: a Soldier who has not scanned yet is
      // exactly who this is for.
      expect(
          find.text('Your photo and the gold chip face you'), findsOneWidget);
      expect(
        find.text('The tall barcode is bottom left, beside the chip'),
        findsOneWidget,
      );
      expect(
        find.text('Not the wide strip the gate guard scans'),
        findsOneWidget,
      );
    });

    testWidgets('every element of the drawing actually renders',
        (tester) async {
      // A schematic is six rectangles and no text, so nothing else in this
      // file would notice one of them laying out at zero. Measured rather
      // than merely found in the tree: a Stack child under the wrong
      // constraints is present, hit-testable and invisible.
      await walkPmcs();
      await pumpPanel(tester);

      final parts = find.descendant(
        of: schematic(),
        matching: find.byType(Container),
      );
      expect(parts, findsNWidgets(6),
          reason: 'body, photo, two name rules, the chip and the target');

      for (final element in parts.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.width, greaterThan(0), reason: 'a collapsed element');
        expect(size.height, greaterThan(0), reason: 'a collapsed element');
      }
    });

    testWidgets('is drawn at CR80 proportions and stays small', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);

      final size = tester.getSize(schematic());
      expect(size.width, SignOffCard.cardWidth);
      expect(size.height, closeTo(SignOffCard.cardWidth * 1.587, 0.01),
          reason: 'the CAC front is printed portrait at 1:1.587');
      // The version a judge killed was 96x152. The size discipline is the
      // whole reason the diagram is allowed to render without a toggle.
      expect(size.height, lessThan(100));
    });

    testWidgets('is offered again after a miss that aiming could fix',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await scan(tester);

      expect(schematic(), findsOneWidget);
    });

    testWidgets('is not offered when the aim is not the problem',
        (tester) async {
      // A diagram of where the barcode lives is noise beside a device that has
      // no camera behind the WebView.
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCamera);
      await scan(tester);

      expect(schematic(), findsNothing);
      expect(
          find.text('Not the wide strip the gate guard scans'), findsNothing);
    });
  });

  group('which control leads', () {
    for (final rejection in [
      CacRejection.noCodeFound,
      CacRejection.codeUnreadable,
      CacRejection.cardTooSmall,
      CacRejection.wrongSideOfCard,
      CacRejection.cameraTimedOut,
    ]) {
      testWidgets('${rejection.name} leads with SCAN AGAIN', (tester) async {
        await walkPmcs();
        await pumpPanel(tester);
        harness.cacScanner.willFail(rejection);
        await scan(tester);

        expect(scanAgainButton, findsOneWidget);
        expect(overrideButton, findsNothing);
        // Demoted, never removed: an operator who knows this card is never
        // going to read must still be able to send the PMCS.
        expect(overrideLink, findsOneWidget);
      });
    }

    testWidgets('noCamera leads with the override', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCamera);
      await scan(tester);

      expect(overrideButton, findsOneWidget);
      expect(scanAgainButton, findsNothing);
      expect(scanAgainLink, findsOneWidget);
    });

    testWidgets('an expired card leads with the override', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      // BBQH is 15 January 2020, long dead against the harness's 2026 clock.
      harness.cacScanner.willRead(cacBarcode(expires: 'BBQH'));
      await scan(tester);

      expect(find.textContaining('That CAC expired'), findsOneWidget);
      expect(overrideButton, findsOneWidget);
      expect(scanAgainLink, findsOneWidget);
    });

    testWidgets('a pre-2012 card leads with the override', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willRead(cacBarcode(securityId: 'ABCDEF'));
      await scan(tester);

      expect(find.textContaining('predates 2012'), findsOneWidget);
      expect(overrideButton, findsOneWidget);
      expect(scanAgainLink, findsOneWidget);
    });

    testWidgets(
        'the override takes the lead once retrying has stopped '
        'helping', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);

      await scan(tester);
      for (var i = 0; i < SignOffCard.maxLeadingRetries; i++) {
        await scan(tester, from: scanAgainButton);
      }

      expect(harness.viewModel.scanAttempts, SignOffCard.maxLeadingRetries + 1);
      expect(overrideButton, findsOneWidget);
      expect(scanAgainLink, findsOneWidget);
    });

    testWidgets(
        'the override keeps its confirmation whichever position it '
        'is in', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      await tapAfterScrolling(tester, overrideLink);

      expect(find.text('Submit unverified?'), findsOneWidget);
      expect(harness.reports.reports, isEmpty);
    });
  });

  group('the escalating hint', () {
    testWidgets('says nothing on the first miss', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await scan(tester);

      expect(find.textContaining('sideways'), findsNothing);
      expect(find.textContaining('shadow'), findsNothing);
    });

    testWidgets('offers the rotation on the second', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await scan(tester);
      await scan(tester, from: scanAgainButton);

      expect(
          find.textContaining('reads at about twice the size'), findsOneWidget);
    });

    testWidgets('moves on to glare on the third', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await scan(tester);
      await scan(tester, from: scanAgainButton);
      await scan(tester, from: scanAgainButton);

      expect(find.textContaining('shadow falls across it'), findsOneWidget);
      expect(find.textContaining('sideways'), findsNothing);
    });

    testWidgets('is not offered where another photograph cannot help',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await scan(tester);
      await scan(tester, from: scanAgainButton);
      expect(find.textContaining('sideways'), findsOneWidget);

      // The count stands, but the card is now the thing being refused.
      harness.cacScanner.willRead(cacBarcode(expires: 'BBQH'));
      await scan(tester, from: scanAgainButton);

      expect(find.textContaining('sideways'), findsNothing);
      expect(find.textContaining('shadow'), findsNothing);
    });
  });

  group('the verified banner', () {
    testWidgets('shows what the app checked the card against', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willRead(cacBarcode());
      await scan(tester);

      expect(find.text('SGT SMITH, JOHN A'), findsOneWidget);
      expect(find.text('Card expires 30 JUN 2028'), findsOneWidget);
      expect(find.textContaining('Book an ID card appointment'), findsNothing);
    });

    testWidgets(
        'a card inside the warning window says so without refusing '
        'the signature', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      // BE1H is 5 April 2026; the harness clock is 24 March 2026.
      harness.cacScanner.willRead(cacBarcode(expires: 'BE1H'));
      await scan(tester);

      expect(
          find.textContaining('This CAC expires in 12 days'), findsOneWidget);
      expect(find.text('Card expires 05 APR 2026'), findsOneWidget);
      // A heads-up, not a refusal. Dressing it as one would teach operators to
      // ignore the real refusals.
      expect(find.widgetWithText(CustomButton, 'SUBMIT PMCS'), findsOneWidget);
    });

    testWidgets('a card with months left raises nothing', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willRead(cacBarcode());
      await scan(tester);

      expect(find.byIcon(Icons.event_busy_outlined), findsNothing);
    });
  });

  group('the gallery advisory', () {
    const line = 'kept its own copy in the gallery';

    testWidgets('rides the verified card', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willRead(cacBarcode());
      await scan(tester);

      expect(find.textContaining(line), findsOneWidget);
    });

    testWidgets('rides the refused card too, where the copies pile up',
        (tester) async {
      // The operator who missed three times has three probable copies in DCIM
      // and is the one least likely to be told otherwise.
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      expect(find.textContaining(line), findsOneWidget);
    });

    testWidgets('is suppressed when there was no camera to photograph with',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.noCamera);
      await scan(tester);

      expect(find.textContaining(line), findsNothing);
    });

    testWidgets('still shows after a timeout, where a frame may well exist',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.cameraTimedOut);
      await scan(tester);

      expect(find.textContaining(line), findsOneWidget);
    });
  });

  group('fits the panel the host actually gives us', () {
    // The risk the aim diagram introduced, stated as a test: a drawing that
    // pushes the two controls off the bottom of a 314px panel at the exact
    // moment the Soldier needs them.
    //
    // Two things are asserted, and neither is an absolute pixel height:
    // flutter_test's font renders every glyph as a full em square, so the
    // card measures roughly twice as tall here as it does on a device and a
    // golden height would be pinned to a lie. What holds instead is the
    // diagram's share of the panel — the reason it is allowed to render with
    // no toggle at all — and that both controls are still reachable and still
    // fire once the operator scrolls to them.

    testWidgets('the diagram costs only a small share of the panel',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);

      final diagram = tester.getSize(find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == SignOffCard.cardWidth,
      ));

      expect(diagram.height / panel.height, lessThan(0.35),
          reason: 'the 96x152 version a judge killed took nearly half the '
              'panel and put SCAN AGAIN below the fold');
    });

    testWidgets('the diagram never sits between the refusal and the button',
        (tester) async {
      // The gap that mattered, and the one being small was not enough to
      // close. With the diagram between the refusal message and SCAN AGAIN,
      // the operator scrolled past the sentence saying what to change, reached
      // the button, and re-shot the card having never read it — which is the
      // only reason the message exists. Measured at the time: SCAN AGAIN at
      // top=84 with the banner at top=-251, both on the same 314px panel.
      //
      // Ordering rather than a pixel gap on purpose: flutter_test renders
      // every glyph as a full em square, so any absolute height here would be
      // pinned to a lie. Where the diagram sits relative to the controls is
      // exact under any font.
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      final diagram = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == SignOffCard.cardWidth,
      );
      await reach(tester, diagram);

      expect(tester.getRect(diagram).top,
          greaterThan(tester.getRect(scanAgainButton).bottom),
          reason: 'the aim guide belongs below both controls in the refused '
              'state, so nothing separates the message from the fix');
      expect(tester.getRect(diagram).top,
          greaterThan(tester.getRect(overrideLink).bottom));
    });

    testWidgets('but it leads in the prompt, where nothing has failed yet',
        (tester) async {
      // The asymmetry is deliberate: here the operator is being aimed rather
      // than corrected, so the drawing is the first thing they meet.
      await walkPmcs();
      await pumpPanel(tester);

      final diagram = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == SignOffCard.cardWidth,
      );
      await reach(tester, diagram);

      expect(tester.getRect(diagram).bottom,
          lessThan(tester.getRect(scanButton).top));
    });

    testWidgets('the card never spills sideways', (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      expect(tester.getSize(find.byType(SignOffCard)).width,
          lessThanOrEqualTo(panel.width));
    });

    testWidgets('SCAN AGAIN is reachable and live with the diagram up',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      await reach(tester, scanAgainButton);
      final box = tester.getRect(scanAgainButton);
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(panel.height),
          reason: 'SCAN AGAIN hangs off the panel');

      await tester.tap(scanAgainButton);
      await tester.pumpAndSettle();
      expect(harness.cacScanner.captureCalls, 2);
    });

    testWidgets(
        'SUBMIT UNVERIFIED is reachable and live with the diagram '
        'and the hint up', (tester) async {
      // The worst case for height: banner, escalating hint, diagram, both
      // controls and both advisories, all at once.
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);
      await scan(tester, from: scanAgainButton);
      expect(
          find.textContaining('reads at about twice the size'), findsOneWidget);

      await reach(tester, overrideLink);
      final box = tester.getRect(overrideLink);
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(panel.height),
          reason: 'the override hangs off the panel');

      await tester.tap(overrideLink);
      await tester.pumpAndSettle();
      expect(find.text('Submit unverified?'), findsOneWidget);
    });

    testWidgets('nothing tappable is under the minimum touch target',
        (tester) async {
      await walkPmcs();
      await pumpPanel(tester);
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await scan(tester);

      for (final finder in [scanAgainButton, overrideLink]) {
        await reach(tester, finder);
        expect(
            tester.getSize(finder).height, greaterThanOrEqualTo(minTouchTarget),
            reason: 'a gloved hand cannot hit it');
      }
    });

    testWidgets('the cancel control is reachable in the scanning state',
        (tester) async {
      final scanner = HangingCacScanner();
      await walkPmcs(scanner: scanner);
      await pumpPanel(tester);
      await reach(tester, scanButton);
      await tester.tap(scanButton);
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('CANCEL SCAN'),
        find.byType(Scrollable).first,
        const Offset(0, -80),
      );
      await tester.pump();

      final box = tester.getRect(find.text('CANCEL SCAN'));
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(panel.height));
    });
  });
}
