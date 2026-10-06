import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/testing.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';

import '../../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacCameraHarness harness;
  const front = CacCameraHarness.cardFront;
  const back = CacCameraHarness.cardBack;
  const agree = CacOcrSession.framesToAgree;

  setUp(() {
    harness = CacCameraHarness()..install();
  });
  tearDown(() => harness.dispose());

  Future<void> start() async {
    harness.scanner.capture();
    await harness.flush();
  }

  group('a digit ML Kit doubts', () {
    // The fifth digit of the DoD ID.
    final shakyDigit = {
      back.single: {18}
    };

    test('keeps its line from giving the DoD ID', () async {
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.readFront();
      harness.doubted = shakyDigit;
      await harness.frames(back, agree + 2);
      expect(harness.scanner.guidance.value.message, contains('10-digit'));
      expect(harness.scanner.guidance.value.message,
          isNot(contains('hold still')));

      harness.doubted = {};
      await harness.frames(back, agree);
      expect((await capture).asFields.dodId, '1087987498');
    });

    test('in a word on the front is no reason to drop the line', () async {
      harness.doubted = {
        '2029 SEP 30': {0, 1, 2, 3},
      };
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.readFront([...front, 'Expires', '2029 SEP 30']);
      await harness.frames(back, agree);
      expect((await capture).asFields.expiresOn, DateTime.utc(2029, 9, 30),
          reason: 'only the DoD ID is held to it');
    });

    test('in a word without digits counts for nothing', () async {
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.readFront();
      harness.doubted = {
        back.single: {0, 1, 2},
      };
      await harness.frames(back, agree);
      expect((await capture).asFields.dodId, '1087987498');
    });
  });

  group('outlines what is being read', () {
    Size uprightCrop() {
      final input = harness.ocrCalls
          .lastWhere((call) => call.method == 'vision#startTextRecognizer')
          .arguments['imageData'] as Map;
      final metadata = input['metadata'] as Map;
      expect(metadata['rotation'], 90);
      return Size((metadata['height'] as num).toDouble(),
          (metadata['width'] as num).toDouble());
    }

    test('the name line, within the card guide', () async {
      await start();
      await harness.frame(front);
      final crop = uprightCrop();
      expect(harness.scanner.highlights.value, [
        Rect.fromLTRB(10 / crop.width, 10 / crop.height, 100 / crop.width,
            30 / crop.height),
      ]);

      await harness.frame(const ['NAME', 'RANK']);
      expect(harness.scanner.highlights.value, isEmpty);
    });

    test('the DoD ID line, then the strip read on its own', () async {
      await start();
      await harness.readFront();
      await harness.frame([...back, 'BLOOD TYPE O POS']);
      final crop = uprightCrop();
      expect(harness.scanner.highlights.value, [
        Rect.fromLTRB(10 / crop.width, 10 / crop.height, 100 / crop.width,
            30 / crop.height),
      ]);

      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPAEDL')];
      await harness.frame(const ['BLOOD TYPE O POS']);
      expect(harness.scanner.highlights.value, [
        Rect.fromLTRB(0, 0, 10 / crop.width, 10 / crop.height),
      ]);
    });

    test('nothing once the scan ends', () async {
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.readFront();
      await harness.frames(back, agree);
      await capture;
      expect(harness.scanner.highlights.value, isEmpty);
    });
  });

  group('diagnostics', () {
    late CacScanDiagnostics diagnostics;

    setUp(() async {
      await harness.dispose();
      diagnostics = CacScanDiagnostics();
      harness = CacCameraHarness(diagnostics: diagnostics)..install();
    });

    test('report every frame, masking what was read', () async {
      final sharp = CacCameraHarness.checkerboard();
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.frame(front, luma: sharp);
      await harness.frame(front, luma: Uint8List(640 * 480));
      await harness.frame(front,
          luma: Uint8List(640 * 480)..fillRange(0, 640 * 480, 255));
      harness.lineConfidence = 0.95;
      await harness.frame(front, luma: sharp);

      final [read, blurred, glary, confident] = diagnostics.reports;
      expect(read.side, CacScanSide.front);
      expect(read.skipped, isNull);
      expect(read.reading, 'name S••••, J•••••');
      expect(read.backing, 1);
      expect(read.linesKept, front.length);
      expect(read.readTime, isNotNull);
      expect(blurred.skipped, CacFrameSkip.blur);
      expect(blurred.reading, isNull);
      expect(glary.skipped, CacFrameSkip.glare);
      expect(glary.glare, 1);
      expect(confident.lowestConfidence, 0.95);
      expect(confident.backing, 2);
      expect(diagnostics.export(), isNot(contains('SMITH')));

      await harness.frames(front, agree, luma: sharp);
      expect(harness.scanner.side.value, CacScanSide.back);
      harness.doubted = {
        back.single: {18},
      };
      harness.codes = [CacCameraHarness.code39('1TPBOMMS10DINPAEDL')];
      await harness.frame(back, luma: sharp);
      final strip = diagnostics.latest!;
      expect(strip.side, CacScanSide.back);
      expect(strip.doubtfulDigits, 1);
      expect(strip.linesDropped, 1);
      expect(strip.barcodes, [CacBarcodeFormat.code39]);
      expect(strip.reading, 'DoD ID ••••••7498');
      expect(diagnostics.export(), isNot(contains('1087987498')));

      harness.doubted = {};
      await harness.frame(back, luma: sharp);
      expect((await capture).asFields.dodId, '1087987498');
    });

    test('start afresh with each scan', () async {
      final first = harness.scanner.capture();
      await harness.flush();
      await harness.frame(front);
      await harness.scanner.cancel();
      await first;
      expect(diagnostics.reports, hasLength(1));

      harness.scanner.capture();
      await harness.flush();
      expect(diagnostics.reports, isEmpty);
    });
  });
}
