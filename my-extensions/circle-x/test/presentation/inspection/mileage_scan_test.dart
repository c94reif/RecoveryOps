import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:cac_ocr/testing.dart';
import 'package:circle_x/domain/vehicle/entities/mileage_reading.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_session.dart';
import 'package:circle_x/domain/vehicle/services/bumper_scanner_strategy.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/inspection/summary/summary_page.dart';
import 'package:circle_x/presentation/inspection/summary/mileage_scan_dialog.dart';

import '../../support/inspection_harness.dart';
import '../../support/fakes.dart';

class _Sessions extends FakeSessionsRepository {
  bool failWrites = false;

  @override
  Future<void> update(PmcsSession session) async {
    if (failWrites) throw StateError('Disk full');
    await super.update(session);
  }
}

class _Scanner implements BumperScannerStrategy {
  @override
  bool isSupported = true;
  int starts = 0;
  int reads = 0;
  int stops = 0;
  int disposals = 0;
  Object? startError;
  Object? readError;
  List<String> lines = ['ODO 012345.6 mi'];
  Completer<List<String>>? pendingRead;
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
    return pendingRead?.future ?? lines;
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  late _Scanner scanner;
  late InspectionHarness harness;
  late _Sessions sessions;
  final field = find.widgetWithText(CustomTextField, 'Odometer reading');

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    scanner = _Scanner();
    getIt.registerFactory<BumperScannerStrategy>(() => scanner);
    sessions = _Sessions();
    harness = InspectionHarness(sessionsRepository: sessions)..register();
    await harness.walkToSummary();
  });

  tearDown(() async {
    await getIt.reset();
    harness.viewModel.dispose();
    clearSnackBars();
  });

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(430, 932)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: SummaryPage())));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    var target = find.text(label);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 150,
          scrollable: find.byType(Scrollable).first);
    }
    target = target.last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<CustomButton>(find.widgetWithText(CustomButton, label))
          .onPressed !=
      null;

  testWidgets('scan requires confirmation, persists on resume and is submitted',
      (tester) async {
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    expect(scanner.starts, 1);
    expect(scanner.reads, 0);
    await tap(tester, 'READ MILEAGE');
    expect(find.text('Is this mileage correct?'), findsOneWidget);
    expect(find.text('12345.6 mi'), findsOneWidget);
    expect(harness.viewModel.session!.mileage, isNull);
    expect(harness.sessions.sessions.single.mileage, isNull);
    expect(scanner.stops, greaterThan(0));
    await tap(tester, 'YES, USE MILEAGE');
    expect(scanner.disposals, 1);
    expect(harness.sessions.sessions.single.mileage!.display, '12345.6 mi');
    expect(find.text('Confirmed mileage: 12345.6 mi'), findsOneWidget);

    final saved = harness.sessions.sessions.single;
    await harness.viewModel.resetToSetup();
    await harness.viewModel.resumeSession(saved);
    expect(harness.viewModel.session!.mileage!.display, '12345.6 mi');
    harness.cacScanner.willReadBarcode(cacBarcode());
    await harness.viewModel.scanCac();
    await harness.viewModel.submit();
    await tester.pumpAndSettle();
    expect(harness.reports.reports.single.mileage!.display, '12345.6 mi');
    expect(harness.entityPort.published.single.mileage!.display, '12345.6 mi');
    expect(harness.meshPort.broadcast.single.mileage!.display, '12345.6 mi');
  });

  testWidgets('rejecting OCR allows corrected digits and units',
      (tester) async {
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    await tap(tester, 'No, enter manually');
    await tester.enterText(field, '54,321.9');
    await tap(tester, 'Miles');
    await tap(tester, 'Kilometers');
    await tap(tester, 'SAVE MILEAGE');
    expect(harness.viewModel.session!.mileage!.display, '54321.9 km');
  });

  testWidgets(
      'multiple readings need selection; cancel keeps the prior reading',
      (tester) async {
    await harness.viewModel
        .saveMileage(MileageReading(value: 888, unit: MileageUnit.miles));
    scanner.lines = ['ODO 12345', '56789 km'];
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    expect(enabled(tester, 'YES, USE MILEAGE'), isFalse);
    await tap(tester, '56789 km');
    expect(enabled(tester, 'YES, USE MILEAGE'), isTrue);
    await tap(tester, 'Cancel');
    expect(harness.viewModel.session!.mileage!.display, '888 mi');
  });

  testWidgets('manual override needs no camera and rejects invalid entries',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Enter mileage manually');
    expect(enabled(tester, 'SAVE MILEAGE'), isFalse);
    for (final invalid in ['-1', '12O34', '12,34', 'NaN']) {
      await tester.enterText(field, invalid);
      await tester.pump();
      expect(enabled(tester, 'SAVE MILEAGE'), isFalse);
    }
    await tester.enterText(field, '0');
    await tap(tester, 'SAVE MILEAGE');
    expect(scanner.starts, 0);
    expect(harness.viewModel.session!.mileage!.value, 0);
  });

  testWidgets('unsupported devices offer manual entry', (tester) async {
    scanner.isSupported = false;
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    expect(find.textContaining('unavailable on this device'), findsOneWidget);
    expect(scanner.starts, 0);
    await tester.enterText(field, '456');
    await tap(tester, 'SAVE MILEAGE');
    expect(harness.viewModel.session!.mileage!.number, '456');
  });

  testWidgets('permission denial and unreadable text leave manual entry usable',
      (tester) async {
    scanner.startError = BumperScanFailure.unavailable;
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    expect(find.textContaining('Camera unavailable'), findsOneWidget);
    scanner.startError = null;
    await tap(tester, 'OPEN CAMERA');
    scanner.lines = ['TRIP 1234', '60 MPH'];
    await tap(tester, 'READ MILEAGE');
    expect(find.textContaining('No odometer reading found'), findsOneWidget);
    await tap(tester, 'Enter mileage manually');
    await tester.enterText(field, '1234');
    await tap(tester, 'SAVE MILEAGE');
    expect(harness.viewModel.session!.mileage!.number, '1234');
  });

  testWidgets('scan errors can retry with fresh candidates', (tester) async {
    scanner.readError = BumperScanFailure.timedOut;
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    expect(find.textContaining('Could not read the dashboard'), findsOneWidget);
    scanner.readError = null;
    await tap(tester, 'OPEN CAMERA');
    await tap(tester, 'READ MILEAGE');
    await tap(tester, 'Scan again');
    expect(find.text('YES, USE MILEAGE'), findsNothing);
    scanner.lines = ['ODO 76543'];
    await tap(tester, 'READ MILEAGE');
    await tap(tester, 'YES, USE MILEAGE');
    expect(harness.viewModel.session!.mileage!.number, '76543');
  });

  testWidgets('late OCR cannot overwrite a manual correction', (tester) async {
    scanner.pendingRead = Completer<List<String>>();
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    await tap(tester, 'Enter mileage manually');
    await tester.enterText(field, '98765');
    scanner.pendingRead!.complete(['12345']);
    await tester.pumpAndSettle();
    await tap(tester, 'SAVE MILEAGE');
    expect(harness.viewModel.session!.mileage!.number, '98765');
  });

  testWidgets('a failed save keeps previous mileage and shows an error',
      (tester) async {
    await harness.viewModel
        .saveMileage(MileageReading(value: 123, unit: MileageUnit.miles));
    sessions.failWrites = true;
    await pump(tester);
    await tap(tester, 'Enter mileage manually');
    await tester.enterText(field, '456');
    await tap(tester, 'SAVE MILEAGE');
    expect(harness.viewModel.session!.mileage!.number, '123');
    expect(sessions.sessions.single.mileage!.number, '123');
    expect(
        find.text('Mileage was not saved. Please try again.'), findsOneWidget);
    expect(harness.viewModel.isBusy, isFalse);
  });

  testWidgets('cancelling an in-flight read discards its late result',
      (tester) async {
    scanner.pendingRead = Completer<List<String>>();
    await pump(tester);
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    await tap(tester, 'Cancel');
    scanner.pendingRead!.complete(['12345']);
    await tester.pumpAndSettle();
    expect(harness.viewModel.session!.mileage, isNull);
    expect(scanner.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing during camera startup ignores its late completion',
      (tester) async {
    scanner.pendingStart = Completer<void>();
    await pump(tester);
    await tester.ensureVisible(find.text('SCAN MILEAGE'));
    await tester.tap(find.text('SCAN MILEAGE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    scanner.pendingStart!.complete();
    await tester.pumpAndSettle();
    expect(find.text('READ MILEAGE'), findsNothing);
    expect(find.textContaining('Camera paused'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tap(tester, 'Cancel');
    expect(harness.viewModel.session!.mileage, isNull);
  });

  testWidgets('manual correction and confirmation fit a small landscape panel',
      (tester) async {
    await pump(tester, size: const Size(380, 330));
    await tap(tester, 'SCAN MILEAGE');
    await tap(tester, 'READ MILEAGE');
    expect(tester.takeException(), isNull);
    await tap(tester, 'No, enter manually');
    tester.view.viewInsets = const FakeViewPadding(bottom: 170);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.enterText(field, '42');
    await tap(tester, 'SAVE MILEAGE');
    expect(find.byType(MileageScanDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
