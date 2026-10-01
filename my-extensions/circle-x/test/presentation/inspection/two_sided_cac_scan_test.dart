import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/core/platform/cac_camera_preview.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/usecases/identity/cac_ocr_session.dart';
import 'package:circle_x/presentation/inspection/summary_page.dart';
import 'package:circle_x/presentation/inspection/viewfinder/cac_viewfinder_android.dart';

import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

// Supplies synthetic OCR lines to the real session and verification pipeline.
class _OcrScanner implements CacScannerStrategy, CacCameraPreview {
  // Create the future in the widget test's zone when capture starts.
  late final Completer<CacCapture> pending = Completer();
  int cancelCalls = 0;

  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  final ValueNotifier<String> guidance = ValueNotifier('');
  @override
  final ValueNotifier<CacScanSide> side = ValueNotifier(CacScanSide.front);
  final session = CacOcrSession();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<CacCapture> capture() {
    guidance.value = session.guidance;
    return pending.future;
  }

  void read(List<String> lines) {
    final result = session.process(lines);
    side.value = session.side;
    guidance.value = session.guidance;
    if (result != null) pending.complete(result);
  }

  void dispose() {
    preview.dispose();
    guidance.dispose();
    side.dispose();
  }
}

void main() {
  late _OcrScanner scanner;
  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    scanner = _OcrScanner();
    harness = InspectionHarness(scanner: scanner);
    harness.register();
    await harness.sessions
        .insert(buildSession(completedPhases: PmcsPhase.values));
    await harness.load();
    await harness.viewModel.resumeSession(harness.viewModel.openSessions.first);
    harness.viewModel.openSummary();
  });

  tearDown(() async {
    await getIt.reset();
    scanner.dispose();
    clearSnackBars();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(370, 314);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: const Scaffold(body: SummaryPage()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> reach(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
        find.text(text), find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await pumpPanel(tester);
    await reach(tester, 'SIGN OFF');
    expect(find.textContaining('Scan the front of your CAC'), findsOneWidget);
    expect(find.text('1. Show the front — your name below the photo'),
        findsOneWidget);
    await reach(tester, 'SCAN CAC');
    await tester.tap(find.text('SCAN CAC'));
    await tester.pump();
  }

  void readFront() {
    scanner.read(['NAME', 'SMITH, JOHN MICHAEL', 'RANK']);
    scanner.read(['NAME', 'SMITH, JOHN MICHAEL', 'RANK']);
  }

  testWidgets('prompts for both sides and submits the name with the DoD ID',
      (tester) async {
    await start(tester);
    expect(find.text('STEP 1 OF 2 — FRONT · NAME'), findsOneWidget);
    expect(find.text('SUBMIT PMCS'), findsNothing);

    readFront();
    await tester.pump();
    expect(find.text('STEP 2 OF 2 — BACK · DoD ID'), findsOneWidget);
    expect(
        find.textContaining('Name read: SMITH, JOHN MICHAEL.'), findsOneWidget);
    expect(find.textContaining('Flip to the BACK'), findsOneWidget);
    expect(find.text('SUBMIT PMCS'), findsNothing);
    expect(harness.viewModel.isSignedOff, isFalse);

    scanner.read(['DoD ID Number 1087987498']);
    scanner.read(['DoD ID Number 1087987498']);
    await tester.pumpAndSettle();
    expect(find.text('SMITH, JOHN MICHAEL'), findsOneWidget);
    expect(find.text('DoD ID 1087987498'), findsOneWidget);
    expect(find.textContaining('gallery'), findsNothing);
    await reach(tester, 'SUBMIT PMCS');
    await tester.tap(find.text('SUBMIT PMCS'));
    await tester.pumpAndSettle();

    final report = harness.reports.reports.single;
    expect(report.operator, 'SMITH, JOHN MICHAEL');
    expect(report.signature!.dodId, '1087987498');
    expect(report.isSignatureVerified, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling after the name leaves the report unsigned',
      (tester) async {
    await start(tester);
    readFront();
    await tester.pump();
    await reach(tester, 'CANCEL SCAN');
    await tester.tap(find.text('CANCEL SCAN'));
    await tester.pumpAndSettle();
    expect(scanner.cancelCalls, 1);
    expect(harness.viewModel.isSignedOff, isFalse);
    expect(find.text('SUBMIT PMCS'), findsNothing);

    // A queued OCR response arriving after cancellation cannot sign anything.
    scanner.read(['1087987498']);
    scanner.read(['1087987498']);
    await tester.pumpAndSettle();
    expect(harness.viewModel.isSignedOff, isFalse);
    expect(harness.reports.reports, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a front timeout offers a retry starting from the photo side',
      (tester) async {
    await start(tester);
    scanner.pending
        .complete(const CacCapture.failed(CacRejection.nameNotFound));
    await tester.pumpAndSettle();
    expect(find.text(CacRejection.nameNotFound.message), findsOneWidget);
    expect(find.text('1. Show the front — your name below the photo'),
        findsOneWidget);
    expect(find.text('SCAN AGAIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the guide changes from portrait front to landscape back',
      (tester) async {
    for (final side in CacScanSide.values) {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
        width: 320,
        height: 240,
        child: CardGuide(side: side),
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
}
