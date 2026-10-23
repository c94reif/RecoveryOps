import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/testing.dart';

import '../../support/identities.dart';

void main() {
  const defaults = CacOcrText();

  Future<CacScanController> pumpCacOcr(
    WidgetTester tester,
    CacScannerStrategy scanner, {
    VoidCallback? onSubmit,
    VoidCallback? onSubmitUnverified,
    CacTypedIdentitySubmit? onSubmitTyped,
    bool scannerAvailable = true,
    bool allowExpired = false,
    CacOcrText text = defaults,
  }) async {
    final controller = CacScanController(
      cacScanner: scanner,
      verifyOperatorIdentity: VerifyOperatorIdentity(
        scanner: scanner,
        parseBarcode: ParseCacBarcode(() => DateTime.utc(2026, 3, 24, 9)),
        allowExpired: allowExpired,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CacOcr(
            controller: controller,
            onSubmit: onSubmit ?? () {},
            onSubmitUnverified: onSubmitUnverified,
            onSubmitTyped: onSubmitTyped,
            scannerAvailable: scannerAvailable,
            text: text,
          ),
        ),
      ),
    ));
    return controller;
  }

  Finder button(String label) => find.widgetWithText(CacButton, label);
  Finder link(String label) => find.widgetWithText(TextButton, label);

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('before a scan', () {
    testWidgets('prompts for the back of the card and draws where to aim',
        (tester) async {
      await pumpCacOcr(tester, FakeCacScanner());

      expect(find.text(defaults.promptBackOnly!), findsOneWidget);
      expect(find.text('Turn the card over — the side the gate scans'),
          findsOneWidget);
      expect(button('SCAN CAC'), findsOneWidget);
    });

    testWidgets('a device with no camera says so instead of drawing the card',
        (tester) async {
      await pumpCacOcr(tester, FakeCacScanner(), scannerAvailable: false);

      expect(find.text(defaults.noCamera!), findsOneWidget);
      expect(find.byType(CacAimGuide), findsNothing);
    });
  });

  group('while scanning', () {
    testWidgets('offers a cancel that lands on a refusal', (tester) async {
      final scanner = HangingCacScanner();
      await pumpCacOcr(tester, scanner);

      await tester.tap(button('SCAN CAC'));
      await tester.pump();
      expect(find.textContaining('wide barcode strip'), findsOneWidget);
      expect(find.text(defaults.scanningNotice!), findsOneWidget);

      await tapAndSettle(tester, find.text('CANCEL SCAN'));
      expect(scanner.cancelCalls, 1);
      expect(find.text('Scan cancelled.'), findsOneWidget);
    });
  });

  group('a verified card', () {
    testWidgets('shows who it read and signs with them', (tester) async {
      final scanner = FakeCacScanner()..willReadBarcode(cacBarcode());
      var submitted = 0;
      await pumpCacOcr(tester, scanner, onSubmit: () => submitted++);

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text('SGT SMITH, JOHN A'), findsOneWidget);
      expect(find.text('US Army · Active Duty'), findsOneWidget);
      expect(find.text('DoD ID 1087987498'), findsOneWidget);
      expect(find.text('Card expires 30 JUN 2028'), findsOneWidget);
      expect(find.text(defaults.galleryAdvisory!), findsOneWidget);

      await tapAndSettle(tester, button('SUBMIT'));
      expect(submitted, 1);

      await tapAndSettle(tester, link('NOT ME — RESCAN'));
      expect(scanner.captureCalls, 2);
    });

    testWidgets('warns about a card about to run out', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CacOcrVerified(
            identity: buildIdentity(cardExpiresOn: DateTime.utc(2026, 4, 5)),
            fromPhoto: false,
            isBusy: false,
            onSubmit: () {},
            onRescan: () {},
          ),
        ),
      ));

      expect(
          find.textContaining('This CAC expires in 12 days'), findsOneWidget);
      expect(find.text(defaults.galleryAdvisory!), findsNothing,
          reason: 'a live preview never hands a photo to the camera app');
    });

    testWidgets('a card accepted past its date is marked expired',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CacOcrVerified(
            identity: buildIdentity(cardExpiresOn: DateTime.utc(2026, 3, 1)),
            fromPhoto: false,
            isBusy: true,
            onSubmit: () {},
            onRescan: () {},
          ),
        ),
      ));

      expect(find.text('This CAC expired 01 MAR 2026. Draw a current card.'),
          findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.event_busy_outlined)).color,
          CacOcrTheme.fromColorScheme(ThemeData().colorScheme).danger,
          reason: 'red for an expired card, amber only for one about to be');
      expect(tester.widget<CacButton>(button('SUBMIT')).onPressed, isNull,
          reason: 'nothing submits while the app is busy');
    });
  });

  group('a refused card', () {
    testWidgets('with no unverified path, scanning again is the only way on',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.noCamera);
      await pumpCacOcr(tester, scanner);

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text(CacRejection.noCamera.message), findsOneWidget);
      expect(button('SCAN AGAIN'), findsOneWidget);
      expect(find.text('SUBMIT UNVERIFIED'), findsNothing);
      expect(find.text(defaults.unverifiedNotice!), findsNothing);
      expect(find.text(defaults.typedHeading!), findsNothing);
      expect(find.text(defaults.galleryAdvisory!), findsNothing);
    });

    testWidgets('a retryable miss leads with SCAN AGAIN over the override',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.codeUnreadable);
      await pumpCacOcr(tester, scanner, onSubmitUnverified: () {});

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(button('SCAN AGAIN'), findsOneWidget);
      expect(link('SUBMIT UNVERIFIED'), findsOneWidget);
      expect(find.byType(CacAimGuide), findsOneWidget);
      expect(find.text(defaults.unverifiedNotice!), findsOneWidget);
    });

    testWidgets('a card no retry can fix leads with the override',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.noCamera);
      var unverified = 0;
      await pumpCacOcr(tester, scanner, onSubmitUnverified: () => unverified++);

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(link('SCAN AGAIN'), findsOneWidget);
      expect(find.byType(CacAimGuide), findsNothing);

      await tapAndSettle(tester, button('SUBMIT UNVERIFIED'));
      expect(unverified, 1);

      await tapAndSettle(tester, link('SCAN AGAIN'));
      expect(scanner.captureCalls, 2);
    });

    testWidgets('the typed fallback hands back the fields as typed',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.codeUnreadable);
      final typed = <String>[];
      await pumpCacOcr(
        tester,
        scanner,
        onSubmitTyped: (
            {required lastName, required firstName, required dodId}) async {
          typed.addAll([lastName, firstName, dodId]);
        },
      );

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text(defaults.typedHeading!), findsOneWidget);
      expect(find.text(defaults.typedNotice!), findsOneWidget);
      final submit = button('SUBMIT WITH TYPED ID');
      expect(tester.widget<CacButton>(submit).onPressed, isNull);

      await tester.enterText(
          find.widgetWithText(TextField, 'Last name'), 'Smith');
      await tester.enterText(
          find.widgetWithText(TextField, 'First name'), 'John');
      final dodId = find.widgetWithText(TextField, 'DoD ID');
      await tester.enterText(dodId, '10879874981');
      await tester.pump();
      expect(find.text('11/10'), findsOneWidget);
      await tester.enterText(dodId, '1087 987 498');
      await tester.pump();
      expect(find.text('10/10'), findsOneWidget);

      await tapAndSettle(tester, submit);
      expect(typed, ['Smith', 'John', '1087 987 498'],
          reason: 'validation is the caller’s, with AttestedIdentity.parse');
    });

    testWidgets('an app can reword the flow without rewording the card',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.expired);
      await pumpCacOcr(
        tester,
        scanner,
        onSubmitUnverified: () {},
        text: CacOcrText(
          scanButton: 'SIGN IN WITH CAC',
          unverifiedButton: 'CONTINUE AS GUEST',
          rejectionMessage: (rejection) => 'Refused: ${rejection.name}.',
        ),
      );

      await tapAndSettle(tester, button('SIGN IN WITH CAC'));
      expect(find.text('Refused: expired.'), findsOneWidget);
      expect(button('CONTINUE AS GUEST'), findsOneWidget);
    });
  });

  group('an expired card', () {
    Color danger() =>
        CacOcrTheme.fromColorScheme(ThemeData().colorScheme).danger;

    testWidgets('is refused in red, with whose card it is and when it ran out',
        (tester) async {
      final scanner = FakeCacScanner()
        ..willReadBarcode(cacBarcode(expires: 'BBQH'));
      await pumpCacOcr(tester, scanner, onSubmitUnverified: () {});

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text('CAC EXPIRED'), findsOneWidget);
      expect(find.text('SGT SMITH, JOHN A'), findsOneWidget);
      expect(find.text('Expired 15 JAN 2020'), findsOneWidget);
      expect(find.text(CacRejection.expired.message), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.event_busy_outlined)).color,
          danger());
      expect(find.text('SUBMIT'), findsNothing);
      expect(button('SUBMIT UNVERIFIED'), findsOneWidget,
          reason: 'another photo of the same card cannot help');
      expect(find.byType(CacAimGuide), findsNothing);
    });

    testWidgets('still says expired when the scanner gave no details',
        (tester) async {
      final scanner = FakeCacScanner()..willFail(CacRejection.expired);
      await pumpCacOcr(tester, scanner);

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text('CAC EXPIRED'), findsOneWidget);
      expect(find.text(CacRejection.expired.message), findsOneWidget);
      expect(find.textContaining('Expired '), findsNothing);
      expect(button('SCAN AGAIN'), findsOneWidget);
    });

    testWidgets('signs, marked expired, where the app allows expired cards',
        (tester) async {
      final scanner = FakeCacScanner()
        ..willReadBarcode(cacBarcode(expires: 'BBQH'));
      var submitted = 0;
      await pumpCacOcr(tester, scanner,
          allowExpired: true, onSubmit: () => submitted++);

      await tapAndSettle(tester, button('SCAN CAC'));
      expect(find.text('CAC EXPIRED'), findsNothing);
      expect(find.text('SGT SMITH, JOHN A'), findsOneWidget);
      expect(find.text('This CAC expired 15 JAN 2020. Draw a current card.'),
          findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.event_busy_outlined)).color,
          danger());

      await tapAndSettle(tester, button('SUBMIT'));
      expect(submitted, 1);
    });
  });
}
