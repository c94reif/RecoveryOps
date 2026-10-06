import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/infrastructure/android/android_cac_scanner.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/testing.dart';

import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

import '../../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacCameraHarness harness;
  const tuning = CacScanTuning();
  const front = CacCameraHarness.cardFront;
  const back = CacCameraHarness.cardBack;
  const short = ['DoD ID Number 108798749'];
  const agree = CacOcrSession.framesToAgree;

  setUp(() {
    harness = CacCameraHarness()..install();
  });
  tearDown(() => harness.dispose());

  Future<void> frames(List<String> text, int count) =>
      harness.frames(text, count);
  Future<void> readFront() => harness.readFront();
  int ocrRuns() => harness.ocrRuns;
  Uint8List checkerboard() => CacCameraHarness.checkerboard();

  test('meters each side and sends cropped pixels through two-sided OCR',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    expect(harness.resolutions, [AndroidCacScanner.startResolution]);
    final frontPoint = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(frontPoint['y'], greaterThan(0.5));
    await readFront();
    final backPoint = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(backPoint['y'], lessThan(0.5));
    final inputs = harness.ocrCalls
        .where((call) => call.method == 'vision#startTextRecognizer');
    final metadata = inputs.first.arguments['imageData']['metadata'] as Map;
    expect(metadata['rotation'], 90);
    expect(metadata['width'], lessThan(640));
    expect(metadata['height'], lessThan(480));
    await frames(back, agree);
    final result = await capture;
    expect(result.asFields.dodId, '1087987498');
    expect(result.asFields.name!.lastName, 'SMITH');
    await harness.scanner.cancel();
    expect(harness.ocrCalls.last.method, 'vision#closeTextRecognizer');
    expect(harness.barcodeCalls.last.method, 'vision#closeBarcodeScanner');
  });

  test('rotation remeters, updates OCR rotation and resets agreement',
      () async {
    final capture = harness.scanner.capture();
    var completed = false;
    capture.then((_) => completed = true);
    await harness.flush();
    await readFront();
    await harness.frame(back);
    await harness.rotate('landscapeLeft');
    await harness.frame(back); // Refocus after rotating, before using frames.
    await frames(back, agree - 1);
    expect(completed, isFalse);
    final input = harness.ocrCalls.last.arguments['imageData'] as Map;
    expect(input['metadata']['rotation'], 0);
    await harness.frame(back);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('tap-to-focus maps visible coordinates and discards older OCR',
      () async {
    final capture = harness.scanner.capture();
    var completed = false;
    capture.then((_) => completed = true);
    await harness.flush();
    await readFront();
    harness.pendingOcr = Completer();
    await harness.frame(back);
    await harness.scanner.focusAt(const Offset(0.25, 0.25));
    final point = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(point['x'], 0.25);
    // The portrait preview is cropped vertically to fit the 4:3 viewfinder.
    expect(point['y'], closeTo(0.359375, 0.00001));
    harness.pendingOcr!.complete(CacCameraHarness.recognized(back));
    await harness.flush();
    harness.pendingOcr = null;
    await frames(back, agree - 1);
    expect(completed, isFalse);
    await harness.frame(back);
    expect((await capture).asFields.dodId, '1087987498');
  });

  for (final rejectPreset in [false, true]) {
    test('repeated short reads retry sharper capture (fallback: $rejectPreset)',
        () async {
      harness.rejectHigherResolution = rejectPreset;
      final capture = harness.scanner.capture();
      await harness.flush();
      await readFront();
      await frames(short, tuning.unreadableFramesBeforeUpgrade);
      expect(harness.resolutions, [
        AndroidCacScanner.startResolution,
        AndroidCacScanner.sharperResolution,
        if (rejectPreset) AndroidCacScanner.startResolution,
      ]);
      expect(harness.scanner.side.value, CacScanSide.back);
      // This attempt must not reopen the camera on every failed frame.
      await frames(short, tuning.unreadableFramesBeforeUpgrade);
      expect(harness.resolutions.length, rejectPreset ? 3 : 2);
      await frames(back, agree);
      final result = await capture;
      expect(result.asFields.dodId, '1087987498');
      expect(result.asFields.name!.lastName, 'SMITH');
    });
  }

  test('unsupported focus controls still allow OCR and exposure metering',
      () async {
    harness.rejectFocus = true;
    final capture = harness.scanner.capture();
    await harness.flush();
    expect(harness.cameraCalls.map((call) => call.method),
        contains('setExposurePoint'));
    await readFront();
    await frames(back, agree);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('fixed-focus cameras skip unsupported metering points', () async {
    harness.supportsMetering = false;
    harness.scanner.capture();
    await harness.flush();
    expect(harness.cameraCalls.map((call) => call.method),
        isNot(contains('setFocusPoint')));
    expect(harness.cameraCalls.map((call) => call.method),
        isNot(contains('setExposurePoint')));
  });

  test('cancelled OCR drains before a fresh attempt and cannot reuse a name',
      () async {
    final first = harness.scanner.capture();
    await harness.flush();
    await readFront();
    harness.pendingOcr = Completer();
    await harness.frame(back);
    final closing = harness.scanner.cancel();
    final retry = harness.scanner.capture();
    await harness.flush();
    expect(harness.resolutions, [AndroidCacScanner.startResolution]);
    expect((await first).rejection, CacRejection.cancelled);
    expect(harness.ocrCalls.map((call) => call.method),
        isNot(contains('vision#closeTextRecognizer')));
    harness.pendingOcr!.complete(CacCameraHarness.recognized(back));
    await closing;
    harness.pendingOcr = null;
    await harness.flush();
    expect(harness.scanner.side.value, CacScanSide.front);
    await readFront();
    await frames(back, agree);
    expect((await retry).asFields.dodId, '1087987498');
  });

  test(
      'cancellation during higher-resolution initialization releases the camera',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await readFront();
    harness.pendingInitialize = Completer();
    await frames(short, tuning.unreadableFramesBeforeUpgrade);
    expect(harness.resolutions, [
      AndroidCacScanner.startResolution,
      AndroidCacScanner.sharperResolution,
    ]);
    final closing = harness.scanner.cancel();
    expect((await capture).rejection, CacRejection.cancelled);
    harness.pendingInitialize!.complete();
    await closing;
    expect(harness.scanner.preview.value, isNull);
    expect(harness.cameraCalls.where((call) => call.method == 'dispose'),
        hasLength(2));
  });

  test('reading the back alone meters the back and closes with no name',
      () async {
    await harness.dispose();
    harness = CacCameraHarness(sides: CacSides.backOnly)..install();
    expect(harness.scanner.sides, CacSides.backOnly);
    expect(harness.scanner.side.value, CacScanSide.back,
        reason: 'the viewfinder draws the back before the camera is up');

    final capture = harness.scanner.capture();
    await harness.flush();
    final point = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(point['y'], lessThan(0.5), reason: 'above the barcode strip');
    expect(harness.scanner.guidance.value.message, contains('BACK'));

    await frames(back, agree);
    final result = await capture;
    expect(result.asFields.dodId, '1087987498');
    expect(result.asFields.name, isNull);
    expect(harness.scanner.side.value, CacScanSide.back);
  });

  test('the rank and expiry printed on the front reach the capture', () async {
    const printed = [
      'NAME',
      'SMITH, JOHN A',
      'RANK',
      'SGT',
      'Expires',
      '2029 SEP 30',
    ];
    final capture = harness.scanner.capture();
    await harness.flush();
    await frames(printed, agree);
    expect(
        harness.scanner.guidance.value.message, contains('SGT SMITH, JOHN A'));
    await frames(back, agree);
    final result = await capture;

    expect(result.asFields.rank, 'SGT');
    expect(result.asFields.expiresOn, DateTime.utc(2029, 9, 30));
  });

  group('barcodes', () {
    test('a front PDF417 ends the scan with the whole record, no flip',
        () async {
      harness.codes = [CacCameraHarness.pdf417(cacBarcode())];
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.frame(const []);

      expect((await capture).asBarcode.raw, cacBarcode());
      expect(harness.scanner.side.value, CacScanSide.front);
      final asked = harness.barcodeCalls
          .firstWhere((call) => call.method == 'vision#startBarcodeScanner');
      expect(asked.arguments['formats'], [0x0800, 0x0002]);
    });

    test('a barcode that is not a CAC record is ignored', () async {
      harness.codes = [CacCameraHarness.pdf417('ANSI 636000080002DL')];
      final capture = harness.scanner.capture();
      var completed = false;
      capture.then((_) => completed = true);
      await harness.flush();
      await harness.frame(const []);

      expect(completed, isFalse);
      await readFront();
    });

    test('the back strip and the printed number agreeing settle it at once',
        () async {
      final capture = harness.scanner.capture();
      await harness.flush();
      await readFront();
      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPAEDL')];
      await harness.frame(back);

      final result = await capture;
      expect(result.asFields.dodId, '1087987498');
      expect(result.asFields.name!.lastName, 'SMITH');
    });

    test('a strip that disagrees with the print never signs', () async {
      final capture = harness.scanner.capture();
      var completed = false;
      capture.then((_) => completed = true);
      await harness.flush();
      await readFront();
      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPBEDL')];
      await frames(back, agree + 1);

      expect(completed, isFalse);
      expect(harness.scanner.guidance.value.message, contains('disagree'));
      harness.codes = [];
      await frames(back, agree);
      expect((await capture).asFields.dodId, '1087987498');
    });

    test('the strip alone still has to read the same on every frame', () async {
      final capture = harness.scanner.capture();
      var completed = false;
      capture.then((_) => completed = true);
      await harness.flush();
      await readFront();
      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPAEDL')];
      await frames(const [], agree - 1);

      expect(completed, isFalse);
      await harness.frame(const []);
      expect((await capture).asFields.dodId, '1087987498');
    });

    test('the back strip shown first asks for the front', () async {
      final capture = harness.scanner.capture();
      var completed = false;
      capture.then((_) => completed = true);
      await harness.flush();
      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPAEDL')];
      await frames(front, agree);

      expect(completed, isFalse);
      expect(harness.scanner.side.value, CacScanSide.front);
      expect(
          harness.scanner.guidance.value.message, contains('That is the back'));
    });

    test('a barcode reader that fails leaves the text to read on its own',
        () async {
      harness.failBarcodes = true;
      final capture = harness.scanner.capture();
      await harness.flush();
      await readFront();
      await frames(back, agree);

      expect((await capture).asFields.dodId, '1087987498');
    });
  });

  group('frames not worth reading', () {
    test('lines ML Kit doubts are left out', () async {
      harness.lineConfidence = 0.2;
      harness.scanner.capture();
      await harness.flush();
      await frames(front, agree + 1);
      expect(harness.scanner.side.value, CacScanSide.front);

      harness.lineConfidence = 0.95;
      await readFront();
    });

    test('a blurred frame is skipped before OCR', () async {
      harness.scanner.capture();
      await harness.flush();
      await harness.frame(front, luma: checkerboard());
      final afterSharp = ocrRuns();
      await harness.frame(front, luma: Uint8List(640 * 480));

      expect(ocrRuns(), afterSharp, reason: 'a flat, blurred frame');
      await harness.frame(front, luma: checkerboard());
      expect(ocrRuns(), afterSharp + 1);
    });

    test('a washed-out frame is skipped and the operator told to tilt',
        () async {
      harness.scanner.capture();
      await harness.flush();
      await harness.frame(front,
          luma: Uint8List(640 * 480)..fillRange(0, 640 * 480, 255));

      expect(ocrRuns(), 0);
      expect(harness.scanner.guidance.value.message, contains('Tilt the card'));
    });

    test('some glare is read through, with the tip shown', () async {
      final luma = checkerboard();
      // 40 of the front crop's 180 rows: enough to coach, not to skip.
      luma.fillRange(640 * 220, 640 * 260, 255);
      harness.scanner.capture();
      await harness.flush();
      await harness.frame(const [], luma: luma);

      expect(ocrRuns(), 1);
      expect(harness.scanner.guidance.value.message, contains('Tilt the card'));
    });
  });
}
