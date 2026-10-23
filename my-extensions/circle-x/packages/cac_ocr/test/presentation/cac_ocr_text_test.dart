import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_card_guide.dart';
import 'package:cac_ocr/testing.dart';

class _LiveScanner implements CacScannerStrategy, CacCameraPreview {
  late final Completer<CacCapture> pending = Completer();

  _LiveScanner(this.sides) : side = ValueNotifier(sides.firstSide);

  @override
  final CacSides sides;
  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  final ValueNotifier<CacGuidance> guidance =
      ValueNotifier(CacInstruction.showFront);
  @override
  final ValueNotifier<CacScanSide> side;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() => pending.future;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> focusAt(Offset point) async {}
}

final marked = CacOcrText(
  promptBothSides: 'T.promptBothSides',
  promptBackOnly: 'T.promptBackOnly',
  noCamera: 'T.noCamera',
  scanButton: 'T.scanButton',
  aimGuideBothSides: const ['T.aimBothSides'],
  aimGuideBackOnly: const ['T.aimBackOnly 1', 'T.aimBackOnly 2'],
  scanningFallback: 'T.scanningFallback',
  cancelButton: 'T.cancelButton',
  scanningNotice: 'T.scanningNotice',
  frontStep: 'T.frontStep',
  backStep: 'T.backStep',
  backOnlyStep: 'T.backOnlyStep',
  frontFocusHint: 'T.frontFocusHint',
  backFocusHint: 'T.backFocusHint',
  frontGuideLabel: 'T.frontGuideLabel',
  backGuideLabel: 'T.backGuideLabel',
  torchOn: 'T.torchOn',
  torchOff: 'T.torchOff',
  guidance: (_) => 'T.guidance',
  verifiedTitle: (identity) => 'T.title ${identity.lastName}',
  verifiedDetail: (_) => 'T.detail',
  dodIdLine: (identity) => 'T.dodId ${identity.dodId}',
  expiresLine: (_) => 'T.expires',
  expiringSoon: (identity) => 'T.expiringSoon ${identity.daysUntilCardExpiry}',
  expiredAdvisory: (_) => 'T.expiredAdvisory',
  submitButton: 'T.submitButton',
  rescanButton: 'T.rescanButton',
  rejectionMessage: (rejection) => 'T.rejection ${rejection.name}',
  expiredTitle: 'T.expiredTitle',
  expiredHolder: (card) => 'T.holder ${card.lastName}',
  expiredOnLine: (_) => 'T.expiredOn',
  retryHint: (attempts, bothSides) => 'T.hint $attempts $bothSides',
  scanAgainButton: 'T.scanAgainButton',
  unverifiedButton: 'T.unverifiedButton',
  unverifiedNotice: 'T.unverifiedNotice',
  galleryAdvisory: 'T.galleryAdvisory',
  typedHeading: 'T.typedHeading',
  typedNotice: 'T.typedNotice',
  lastNameLabel: 'T.lastName',
  firstNameLabel: 'T.firstName',
  dodIdLabel: 'T.dodIdLabel',
  dodIdHint: 'T.dodIdHint',
  typedSubmitButton: 'T.typedSubmitButton',
);

const quiet = CacOcrText(
  promptBothSides: null,
  promptBackOnly: null,
  noCamera: null,
  aimGuideBothSides: [],
  aimGuideBackOnly: [],
  scanningNotice: null,
  verifiedDetail: null,
  dodIdLine: null,
  expiresLine: null,
  expiringSoon: null,
  expiredAdvisory: null,
  expiredHolder: null,
  expiredOnLine: null,
  rescanButton: null,
  retryHint: null,
  unverifiedNotice: null,
  galleryAdvisory: null,
  typedHeading: null,
  typedNotice: null,
  dodIdHint: null,
);

void main() {
  final shown = <String>{};

  void collect(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      shown.add(text.data ?? text.textSpan!.toPlainText());
    }
  }

  setUp(shown.clear);

  Future<CacScanController> pump(
    WidgetTester tester,
    CacScannerStrategy scanner, {
    required CacOcrText text,
    bool scannerAvailable = true,
    bool showAimGuide = true,
    int maxLeadingRetries = CacOcr.defaultMaxLeadingRetries,
    bool unverified = true,
    bool typed = true,
  }) async {
    final controller = CacScanController(
      cacScanner: scanner,
      verifyOperatorIdentity: VerifyOperatorIdentity(
        scanner: scanner,
        parseBarcode: ParseCacBarcode(() => DateTime.utc(2028, 6, 20)),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CacOcr(
            controller: controller,
            scannerAvailable: scannerAvailable,
            showAimGuide: showAimGuide,
            maxLeadingRetries: maxLeadingRetries,
            onSubmit: () {},
            onSubmitUnverified: unverified ? () {} : null,
            onSubmitTyped: typed
                ? ({required lastName, required firstName, required dodId}) =>
                    Future<void>.value()
                : null,
            text: text,
          ),
        ),
      ),
    ));
    collect(tester);
    return controller;
  }

  Future<void> scanWith(WidgetTester tester, CacScanController controller,
      FakeCacScanner scanner, CacCapture result) async {
    scanner.result = result;
    await controller.scan();
    await tester.pumpAndSettle();
    collect(tester);
  }

  group('every word comes from CacOcrText', () {
    void expectOnlyMarked() {
      final foreign = shown.where((line) =>
          !line.startsWith('T.') &&
          line != '·  ' &&
          !RegExp(r'^\d+/10$').hasMatch(line));
      expect(foreign, isEmpty, reason: 'shown: $shown');
    }

    testWidgets('through a photo scan, its refusals and the typed fallback',
        (tester) async {
      final scanner = FakeCacScanner();
      final controller = await pump(tester, scanner, text: marked);
      expect(shown, containsAll(['T.promptBackOnly', 'T.aimBackOnly 2']));

      await scanWith(tester, controller, scanner,
          const CacCapture.failed(CacRejection.codeUnreadable));
      await scanWith(tester, controller, scanner,
          const CacCapture.failed(CacRejection.codeUnreadable));
      expect(
          shown,
          containsAll([
            'T.rejection codeUnreadable',
            'T.hint 2 false',
            'T.scanAgainButton',
            'T.unverifiedButton',
            'T.unverifiedNotice',
            'T.galleryAdvisory',
            'T.TYPEDHEADING',
            'T.typedNotice',
            'T.lastName',
            'T.dodIdLabel',
            'T.typedSubmitButton',
          ]));

      await scanWith(tester, controller, scanner,
          CacCapture.barcode(cacBarcode(expires: 'BBQH')));
      expect(
          shown,
          containsAll([
            'T.expiredTitle',
            'T.holder SMITH',
            'T.expiredOn',
            'T.rejection expired',
          ]));

      await scanWith(tester, controller, scanner,
          CacCapture.barcode(cacBarcode(expires: 'BER2')));
      expect(
          shown,
          containsAll([
            'T.title SMITH',
            'T.detail',
            'T.dodId 1087987498',
            'T.expires',
            'T.expiringSoon 10',
            'T.submitButton',
            'T.rescanButton',
          ]));
      expectOnlyMarked();
    });

    testWidgets('while a photo scan is open, and with no camera at all',
        (tester) async {
      final scanner = HangingCacScanner();
      await pump(tester, scanner, text: marked, scannerAvailable: false);
      expect(shown, contains('T.noCamera'));

      await tester.tap(find.text('T.scanButton'));
      await tester.pump();
      collect(tester);
      expect(
          shown,
          containsAll(
              ['T.scanningFallback', 'T.cancelButton', 'T.scanningNotice']));
      expectOnlyMarked();
    });

    for (final sides in CacSides.values) {
      testWidgets('through a live ${sides.name} scan', (tester) async {
        final scanner = _LiveScanner(sides);
        await pump(tester, scanner, text: marked);
        await tester.tap(find.text('T.scanButton'));
        await tester.pump();
        collect(tester);
        scanner.side.value = CacScanSide.back;
        await tester.pump();
        collect(tester);

        expect(
            shown,
            containsAll(sides == CacSides.backOnly
                ? ['T.promptBackOnly', 'T.backOnlyStep', 'T.backFocusHint']
                : [
                    'T.promptBothSides',
                    'T.aimBothSides',
                    'T.frontStep',
                    'T.frontFocusHint',
                    'T.backStep',
                    'T.backFocusHint',
                  ]));
        expect(shown, contains('T.guidance'),
            reason: 'the scanner says what to coach; this says the words');
        expectOnlyMarked();
      });
    }

    testWidgets('on the card guide drawn over the camera', (tester) async {
      for (final side in CacScanSide.values) {
        await tester.pumpWidget(MaterialApp(
          home: SizedBox(
              width: 320,
              height: 240,
              child: CacCardGuide(side: side, text: marked)),
        ));
        collect(tester);
      }

      expect(shown, {'T.frontGuideLabel', 'T.backGuideLabel'});
    });

    testWidgets('when a card runs out after it was scanned', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CacOcrVerified(
            identity: CacIdentity(
              dodId: '1087987498',
              firstName: 'JOHN',
              lastName: 'SMITH',
              cardExpiresOn: DateTime.utc(2026, 3, 1),
              verifiedAt: DateTime.utc(2026, 3, 24),
            ),
            fromPhoto: false,
            isBusy: false,
            onSubmit: () {},
            onRescan: () {},
            text: marked,
          ),
        ),
      ));
      collect(tester);

      expect(shown, contains('T.expiredAdvisory'));
      expectOnlyMarked();
    });
  });

  group('a line set to null is left out', () {
    testWidgets('leaving each state its essentials', (tester) async {
      final scanner = FakeCacScanner();
      final controller = await pump(tester, scanner, text: quiet);
      expect(shown, {'SCAN CAC'},
          reason: 'the card diagram stays, with no lines beside it');
      expect(find.byType(CacAimGuide), findsOneWidget);

      shown.clear();
      await scanWith(tester, controller, scanner,
          const CacCapture.failed(CacRejection.codeUnreadable));
      await scanWith(tester, controller, scanner,
          const CacCapture.failed(CacRejection.codeUnreadable));
      expect(
          shown,
          {
            CacRejection.codeUnreadable.message,
            'SCAN AGAIN',
            'SUBMIT UNVERIFIED',
            'Last name',
            'First name',
            'DoD ID',
            '0/10',
            'SUBMIT WITH TYPED ID',
          },
          reason: 'no hint, notices, gallery advice or typed heading');

      shown.clear();
      await scanWith(tester, controller, scanner,
          CacCapture.barcode(cacBarcode(expires: 'BER2')));
      expect(shown, {'SGT SMITH, JOHN A', 'SUBMIT'},
          reason: 'no detail, number, expiry, advisory or rescan link');
    });

    testWidgets('and an unset notice leaves no gap behind', (tester) async {
      await pump(tester, HangingCacScanner(),
          text: quiet, scannerAvailable: false);
      expect(shown, {'SCAN CAC'});

      await tester.tap(find.text('SCAN CAC'));
      await tester.pump();
      expect(find.text(quiet.scanningFallback), findsOneWidget);
      expect(find.text('CANCEL SCAN'), findsOneWidget);
      expect(find.textContaining('Camera frames'), findsNothing);
    });
  });

  testWidgets('the card diagram can be left out entirely', (tester) async {
    final scanner = FakeCacScanner();
    final controller = await pump(tester, scanner,
        text: const CacOcrText(), showAimGuide: false);
    expect(find.byType(CacAimGuide), findsNothing);

    await scanWith(tester, controller, scanner,
        const CacCapture.failed(CacRejection.noCodeFound));
    expect(find.text('SCAN AGAIN'), findsOneWidget);
    expect(find.byType(CacAimGuide), findsNothing);
  });

  testWidgets('an app sets how many misses SCAN AGAIN leads for',
      (tester) async {
    final scanner = FakeCacScanner();
    final controller = await pump(tester, scanner,
        text: const CacOcrText(), maxLeadingRetries: 1);
    Finder button(String label) => find.widgetWithText(CacButton, label);

    await scanWith(tester, controller, scanner,
        const CacCapture.failed(CacRejection.codeUnreadable));
    expect(button('SCAN AGAIN'), findsOneWidget);

    await scanWith(tester, controller, scanner,
        const CacCapture.failed(CacRejection.codeUnreadable));
    expect(button('SUBMIT UNVERIFIED'), findsOneWidget,
        reason: 'the override leads once one retry has not helped');
    expect(find.widgetWithText(TextButton, 'SCAN AGAIN'), findsOneWidget);
  });
}
