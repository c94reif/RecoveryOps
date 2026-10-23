import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_live_preview.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_card_guide.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder_live.dart'
    show CacViewfinder;
import 'package:cac_ocr/testing.dart';

class _LiveScanner implements CacScannerStrategy, CacCameraPreview {
  late final Completer<CacCapture> pending = Completer();
  final focused = <Offset>[];

  _LiveScanner([this.sides = CacSides.frontAndBack])
      : side = ValueNotifier(sides.firstSide);

  @override
  final CacSides sides;

  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  final ValueNotifier<CacGuidance> guidance =
      ValueNotifier(CacInstruction.startingCamera);
  @override
  final ValueNotifier<CacScanSide> side;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() => pending.future;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> focusAt(Offset point) async => focused.add(point);
}

class _PreviewCamera extends CameraController {
  _PreviewCamera()
      : super(
          const CameraDescription(
              name: 'rear',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90),
          ResolutionPreset.high,
        ) {
    value =
        value.copyWith(isInitialized: true, previewSize: const Size(640, 480));
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
}

void main() {
  test('only a live-preview scanner gets a viewfinder and both sides', () {
    final live = _LiveScanner();
    final photo = FakeCacScanner();

    expect(buildCacViewfinder(live), isA<CacViewfinder>());
    expect(scansBothCacSides(live), isTrue);
    expect(buildCacViewfinder(photo), isNull);
    expect(scansBothCacSides(photo), isFalse);
  });

  testWidgets('walks the operator from the front to the back', (tester) async {
    final scanner = _LiveScanner();
    final controller = CacScanController(
      cacScanner: scanner,
      verifyOperatorIdentity: VerifyOperatorIdentity(
          scanner: scanner, parseBarcode: const ParseCacBarcode()),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CacOcr(controller: controller, onSubmit: () {}),
        ),
      ),
    ));

    expect(find.text(const CacOcrText().promptBothSides!), findsOneWidget);
    expect(find.text('1. Show the front — your name below the photo'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(CacButton, 'SCAN CAC'));
    await tester.pump();
    expect(find.text('STEP 1 OF 2 — FRONT · NAME'), findsOneWidget);
    expect(find.text('Tap your name to focus'), findsOneWidget);
    expect(find.text('Starting camera…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'no camera frames yet');

    scanner.side.value = CacScanSide.back;
    scanner.guidance.value = CacInstruction.cardRead;
    await tester.pump();
    expect(find.text('STEP 2 OF 2 — BACK · DoD ID'), findsOneWidget);
    expect(find.text('Tap the DoD ID number to focus'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);

    scanner.pending.complete(const CacCapture.fields('1087987498',
        name: (firstName: 'JOHN MICHAEL', lastName: 'SMITH')));
    await tester.pumpAndSettle();
    expect(find.text('SMITH, JOHN MICHAEL'), findsOneWidget);
    expect(find.text('DoD ID 1087987498'), findsOneWidget);
    expect(find.text(const CacOcrText().galleryAdvisory!), findsNothing);
  });

  testWidgets('a back-only scanner never asks for the front', (tester) async {
    final scanner = _LiveScanner(CacSides.backOnly);
    final controller = CacScanController(
      cacScanner: scanner,
      verifyOperatorIdentity: VerifyOperatorIdentity(
          scanner: scanner, parseBarcode: const ParseCacBarcode()),
    );
    addTearDown(controller.dispose);
    const text = CacOcrText();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CacOcr(controller: controller, onSubmit: () {}),
        ),
      ),
    ));

    expect(scansBothCacSides(scanner), isFalse);
    expect(hasCacLivePreview(scanner), isTrue);
    expect(find.text(text.promptBackOnly!), findsOneWidget);
    expect(find.text(text.aimGuideBackOnly.first), findsOneWidget);
    expect(find.text(text.aimGuideBothSides.first), findsNothing);

    await tester.tap(find.widgetWithText(CacButton, 'SCAN CAC'));
    await tester.pump();
    expect(find.text(text.backOnlyStep), findsOneWidget);
    expect(find.text(text.frontStep), findsNothing);
    expect(find.text(text.backFocusHint), findsOneWidget);

    scanner.pending.complete(const CacCapture.fields('1087987498'));
    await tester.pumpAndSettle();
    expect(find.text('DoD ID 1087987498'), findsOneWidget,
        reason: 'with no name the title is the number; it is not repeated');
    expect(find.text(text.galleryAdvisory!), findsNothing,
        reason: 'a live preview hands no photo to the camera app');
  });

  testWidgets('frames from the camera show under the guide and take taps',
      (tester) async {
    final scanner = _LiveScanner();
    final camera = _PreviewCamera();
    scanner.preview.value = camera;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 320, child: CacViewfinder(scanner: scanner)),
      ),
    ));

    expect(find.byType(CacLivePreview), findsOneWidget);
    expect(find.byType(CacCardGuide), findsOneWidget);
    await tester.tap(find.byType(CacLivePreview));
    await tester.pump(const Duration(seconds: 1));
    expect(scanner.focused, [const Offset(0.5, 0.5)]);

    await tester.pumpWidget(const SizedBox());
    await camera.dispose();
  });

  testWidgets('the guide changes from portrait front to landscape back',
      (tester) async {
    for (final side in CacScanSide.values) {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
        width: 320,
        height: 240,
        child: CacCardGuide(side: side),
      ))));
      final brackets = find.byWidgetPredicate((widget) =>
          widget is CustomPaint && widget.painter is CornerBracketsPainter);
      final size = tester.getSize(brackets);
      expect(
          size.width / size.height,
          closeTo(
              side == CacScanSide.front
                  ? 1 / CacViewfinder.cardAspect
                  : CacViewfinder.cardAspect,
              0.001));
      expect(
          find.text(side == CacScanSide.front
              ? 'FRONT — NAME BELOW YOUR PHOTO'
              : 'BACK — DoD ID NUMBER ABOVE THE STRIP'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('the brackets repaint only when their colour changes', () {
    final green = CornerBracketsPainter(Colors.green);

    expect(green.shouldRepaint(CornerBracketsPainter(Colors.green)), isFalse);
    expect(green.shouldRepaint(CornerBracketsPainter(Colors.red)), isTrue);
  });
}
