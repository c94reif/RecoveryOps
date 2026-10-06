import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_card_guide.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder_live.dart'
    show CacViewfinder;

class _FeedbackScanner
    implements CacScannerStrategy, CacCameraPreview, CacLiveFeedback {
  final pending = Completer<CacCapture>();
  final torchRequests = <bool>[];

  _FeedbackScanner({this.diagnostics});

  @override
  final CacScanDiagnostics? diagnostics;
  @override
  final CacSides sides = CacSides.frontAndBack;
  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  final ValueNotifier<CacGuidance> guidance =
      ValueNotifier(CacInstruction.startingCamera);
  @override
  final ValueNotifier<CacScanSide> side = ValueNotifier(CacScanSide.front);
  @override
  final ValueNotifier<List<Rect>> highlights = ValueNotifier(const []);
  @override
  final ValueNotifier<bool?> torch = ValueNotifier(false);

  @override
  Future<void> setTorch(bool on) async {
    torchRequests.add(on);
    torch.value = on;
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() => pending.future;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> focusAt(Offset point) async {}
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
  Finder highlightsPainter() => find.byWidgetPredicate((widget) =>
      widget is CustomPaint &&
      widget.foregroundPainter is ReadHighlightsPainter);

  Future<_PreviewCamera> pumpViewfinder(
      WidgetTester tester, _FeedbackScanner scanner,
      {CacOcrText text = const CacOcrText()}) async {
    final camera = _PreviewCamera();
    scanner.preview.value = camera;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
            width: 320, child: CacViewfinder(scanner: scanner, text: text)),
      ),
    ));
    addTearDown(camera.dispose);
    return camera;
  }

  group('the torch switch', () {
    testWidgets('turns the light on and off, labelled for each',
        (tester) async {
      final scanner = _FeedbackScanner();
      await pumpViewfinder(tester, scanner);

      await tester.tap(find.byTooltip('Turn on the light'));
      await tester.pump();
      expect(scanner.torchRequests, [true]);
      expect(find.byIcon(Icons.flashlight_on), findsOneWidget);

      await tester.tap(find.byTooltip('Turn off the light'));
      await tester.pump();
      expect(scanner.torchRequests, [true, false]);
      expect(find.byIcon(Icons.flashlight_off), findsOneWidget);
    });

    testWidgets('takes its labels from CacOcrText', (tester) async {
      final scanner = _FeedbackScanner();
      await pumpViewfinder(tester, scanner,
          text: const CacOcrText(torchOn: 'T.on', torchOff: 'T.off'));
      expect(find.byTooltip('T.on'), findsOneWidget);

      scanner.torch.value = true;
      await tester.pump();
      expect(find.byTooltip('T.off'), findsOneWidget);
    });

    testWidgets('is gone where the camera has no torch', (tester) async {
      final scanner = _FeedbackScanner();
      await pumpViewfinder(tester, scanner);
      scanner.torch.value = null;
      await tester.pump();

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('waits for the camera', (tester) async {
      final scanner = _FeedbackScanner();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(width: 320, child: CacViewfinder(scanner: scanner))),
      ));

      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('what is being read', () {
    testWidgets('is outlined on the card guide as it changes', (tester) async {
      final scanner = _FeedbackScanner();
      await pumpViewfinder(tester, scanner);
      expect(highlightsPainter(), findsNothing);

      const read = [Rect.fromLTRB(0.1, 0.6, 0.7, 0.7)];
      scanner.highlights.value = read;
      await tester.pump();
      final painter = tester
          .widget<CustomPaint>(highlightsPainter())
          .foregroundPainter as ReadHighlightsPainter;
      expect(painter.highlights, read);
      expect(tester.takeException(), isNull);

      scanner.highlights.value = const [];
      await tester.pump();
      expect(highlightsPainter(), findsNothing);
    });

    test('repaints only when the outlines or their colour change', () {
      const rects = [Rect.fromLTRB(0, 0, 0.5, 0.5)];
      final green = ReadHighlightsPainter(rects, Colors.green);

      expect(green.shouldRepaint(ReadHighlightsPainter(rects, Colors.green)),
          isFalse);
      expect(
          green.shouldRepaint(ReadHighlightsPainter(
              const [Rect.fromLTRB(0, 0, 0.5, 0.5)], Colors.green)),
          isFalse);
      expect(green.shouldRepaint(ReadHighlightsPainter(rects, Colors.red)),
          isTrue);
      expect(green.shouldRepaint(ReadHighlightsPainter(const [], Colors.green)),
          isTrue);
    });

    testWidgets('a guide given no outlines draws none', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
            width: 320,
            height: 240,
            child: CacCardGuide(side: CacScanSide.back)),
      ));
      expect(highlightsPainter(), findsNothing);
    });
  });

  group('the scan log', () {
    late List<String> copied;

    setUp(() {
      copied = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    CacFrameReport frame(double sharpness) => CacFrameReport(
          at: Duration(milliseconds: sharpness.toInt()),
          side: CacScanSide.front,
          sharpness: sharpness,
          sharpest: 100,
          glare: 0,
          skipped: CacFrameSkip.blur,
        );

    Future<CacScanController> pumpSignOff(
        WidgetTester tester, CacScannerStrategy scanner) async {
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
      return controller;
    }

    testWidgets('sits under the sign-off and copies the whole log',
        (tester) async {
      final diagnostics = CacScanDiagnostics();
      await pumpSignOff(tester, _FeedbackScanner(diagnostics: diagnostics));
      expect(find.text('SCAN CAC'), findsOneWidget);
      expect(find.text('SCAN DIAGNOSTICS'), findsOneWidget);
      final copy = find.widgetWithText(TextButton, 'COPY LOG');
      expect(tester.widget<TextButton>(copy).onPressed, isNull,
          reason: 'nothing to copy yet');

      for (var sharpness = 1; sharpness <= 8; sharpness++) {
        diagnostics.add(frame(sharpness.toDouble()));
      }
      await tester.pump();
      expect(find.text(diagnostics.headline), findsOneWidget);
      expect(find.text(frame(1).toLine()), findsNothing,
          reason: 'only the latest frames are shown');
      expect(find.text(frame(8).toLine()), findsOneWidget);
      expect(find.text(frame(3).toLine()), findsOneWidget);

      await tester.tap(copy);
      expect(copied, [diagnostics.export()]);
    });

    testWidgets('stays after the scan, to be copied', (tester) async {
      final scanner = _FeedbackScanner(diagnostics: CacScanDiagnostics());
      final controller = await pumpSignOff(tester, scanner);
      unawaited(controller.scan());
      await tester.pump();
      expect(find.text('SCAN DIAGNOSTICS'), findsOneWidget);

      scanner.pending
          .complete(const CacCapture.failed(CacRejection.noCodeFound));
      await tester.pumpAndSettle();
      expect(find.text('SCAN AGAIN'), findsOneWidget);
      expect(find.text('SCAN DIAGNOSTICS'), findsOneWidget);
    });

    testWidgets('is left out unless the scanner keeps one', (tester) async {
      await pumpSignOff(tester, _FeedbackScanner());
      expect(find.text('SCAN DIAGNOSTICS'), findsNothing);
    });
  });
}
