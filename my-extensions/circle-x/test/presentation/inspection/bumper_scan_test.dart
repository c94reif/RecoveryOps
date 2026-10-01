import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/platform/ocr_camera_preview.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/inspection/bumper_scan_dialog.dart';
import 'package:circle_x/presentation/inspection/setup_page.dart';

import '../../support/inspection_harness.dart';

class _Scanner implements BumperScannerStrategy, OcrCameraPreview {
  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  bool isSupported = true;
  int starts = 0;
  int reads = 0;
  int stops = 0;
  int disposals = 0;
  Object? startError;
  Object? readError;
  List<String> lines = ['4ID 1-8IN', 'A - 11'];
  Completer<List<String>>? pending;
  Completer<void>? pendingStart;

  @override
  Future<void> start() async {
    starts++;
    if (startError != null) throw startError!;
    await pendingStart?.future;
  }

  @override
  Future<List<String>> read() async {
    reads++;
    if (readError != null) throw readError!;
    return pending?.future ?? lines;
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  late _Scanner scanner;
  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    scanner = _Scanner();
    getIt.registerFactory<BumperScannerStrategy>(() => scanner);
    harness = InspectionHarness();
    harness.register();
    await harness.load();
  });

  tearDown(() async {
    await getIt.reset();
    scanner.preview.dispose();
    clearSnackBars();
  });

  final bumperField = find.widgetWithText(CustomTextField, 'Bumper Number');
  final selectedField =
      find.widgetWithText(CustomTextField, 'Selected bumper number');
  final useButton = find.widgetWithText(CustomButton, 'USE BUMPER NUMBER');

  bool canUse(WidgetTester tester) =>
      tester.widget<CustomButton>(useButton).onPressed != null;

  String bumper(WidgetTester tester) =>
      tester.widget<CustomTextField>(bumperField).controller.text;

  Future<void> pump(WidgetTester tester, {String? initial}) async {
    await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const Scaffold(body: SetupPage())));
    await tester.pumpAndSettle();
    if (initial != null) await tester.enterText(bumperField, initial);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Scan bumper number'));
    await tester.tap(find.byTooltip('Scan bumper number'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'reads only on request and fills only after explicit selection and use',
      (tester) async {
    await pump(tester);
    await open(tester);
    expect(scanner.starts, 1);
    expect(scanner.reads, 0);
    expect(canUse(tester), isFalse);
    await tap(tester, 'READ MARKINGS');
    expect(scanner.reads, 1);
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => !chip.selected),
        isTrue);
    expect(bumper(tester), isEmpty);
    expect(canUse(tester), isFalse);
    await tap(tester, 'A-11');
    expect(canUse(tester), isTrue);
    expect(bumper(tester), isEmpty);
    expect(harness.viewModel.session, isNull);
    await tap(tester, 'USE BUMPER NUMBER');
    expect(bumper(tester), 'A-11');
    expect(harness.viewModel.session, isNull);
    expect(scanner.stops, 1);
    await tap(tester, 'BEGIN PMCS');
    expect(harness.viewModel.session!.bumperNumber, 'A-11');
  });

  testWidgets('even a single detected marking must be selected',
      (tester) async {
    scanner.lines = ['HQ-66'];
    await pump(tester);
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    expect(canUse(tester), isFalse);
    expect(find.byType(FilterChip), findsOneWidget);
    expect(bumper(tester), isEmpty);
  });

  testWidgets('combines selected lines in order and allows correction',
      (tester) async {
    scanner.lines = ['4ID', '11', 'A'];
    await pump(tester);
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    await tap(tester, 'A');
    await tap(tester, '11');
    expect(
        tester.widget<CustomTextField>(selectedField).controller.text, 'A 11');
    await tester.enterText(selectedField, 'a-11');
    await tester.pump();
    await tap(tester, 'USE BUMPER NUMBER');
    expect(bumper(tester), 'A-11');
  });

  testWidgets('deselecting everything or clearing the draft disables use',
      (tester) async {
    await pump(tester);
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    await tap(tester, 'A-11');
    await tester.enterText(selectedField, '   ');
    await tester.pump();
    expect(canUse(tester), isFalse);
    await tap(tester, 'A-11');
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(selectedField, findsNothing);
    expect(canUse(tester), isFalse);
  });

  testWidgets('cancel preserves a typed number even after selecting another',
      (tester) async {
    await pump(tester, initial: 'B-22');
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    await tap(tester, 'A-11');
    await tap(tester, 'Cancel');
    expect(bumper(tester), 'B-22');
    expect(scanner.stops, 1);
  });

  testWidgets(
      'a reread clears the old selection and never silently replaces it',
      (tester) async {
    await pump(tester);
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    await tap(tester, 'A-11');
    scanner.lines = ['B-22'];
    await tap(tester, 'READ MARKINGS');
    expect(find.text('A-11'), findsNothing);
    expect(find.text('B-22'), findsOneWidget);
    expect(canUse(tester), isFalse);
    expect(bumper(tester), isEmpty);
  });

  testWidgets(
      'late OCR after cancellation cannot overwrite the field or a new scan',
      (tester) async {
    await pump(tester, initial: 'B-22');
    await open(tester);
    final pending = Completer<List<String>>();
    scanner.pending = pending;
    await tap(tester, 'READ MARKINGS');
    expect(canUse(tester), isFalse);
    await tap(tester, 'Cancel');
    scanner.pending = null;
    await open(tester);
    pending.complete(['WRONG-99']);
    await tester.pumpAndSettle();
    expect(find.text('WRONG-99'), findsNothing);
    expect(canUse(tester), isFalse);
    expect(bumper(tester), 'B-22');
  });

  testWidgets(
      'empty reads and OCR failures offer retry without changing the field',
      (tester) async {
    scanner.lines = [];
    await pump(tester, initial: 'B-22');
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    expect(find.textContaining('No markings found'), findsOneWidget);
    expect(canUse(tester), isFalse);
    scanner.readError = BumperScanFailure.timedOut;
    await tap(tester, 'READ MARKINGS');
    expect(find.text(BumperScanFailure.timedOut.message), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(bumper(tester), 'B-22');
  });

  testWidgets('camera failure leaves a retry and manual entry available',
      (tester) async {
    scanner.startError = BumperScanFailure.unavailable;
    await pump(tester, initial: 'B-22');
    await open(tester);
    expect(find.text(BumperScanFailure.unavailable.message), findsOneWidget);
    expect(canUse(tester), isFalse);
    scanner.startError = null;
    await tap(tester, 'OPEN CAMERA');
    expect(find.text('READ MARKINGS'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(bumper(tester), 'B-22');
  });

  testWidgets(
      'unsupported platforms retain manual entry without a dead scan control',
      (tester) async {
    scanner.isSupported = false;
    await pump(tester, initial: 'B-22');
    expect(find.byTooltip('Scan bumper number'), findsNothing);
    expect(bumper(tester), 'B-22');
    await tap(tester, 'BEGIN PMCS');
    expect(harness.viewModel.session!.bumperNumber, 'B-22');
  });

  testWidgets('selection and confirm remain reachable in a small panel',
      (tester) async {
    tester.view.physicalSize = const Size(370, 314);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    await open(tester);
    await tap(tester, 'READ MARKINGS');
    await tap(tester, 'A-11');
    expect(tester.takeException(), isNull);
    await tap(tester, 'USE BUMPER NUMBER');
    expect(find.byType(BumperScanDialog), findsNothing);
    expect(bumper(tester), 'A-11');
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding closes the camera and requires an explicit reopen',
      (tester) async {
    await pump(tester);
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(scanner.stops, 1);
    expect(find.text('OPEN CAMERA'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(scanner.starts, 1);
    await tap(tester, 'OPEN CAMERA');
    expect(scanner.starts, 2);
  });
}
