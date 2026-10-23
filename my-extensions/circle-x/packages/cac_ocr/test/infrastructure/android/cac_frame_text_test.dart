import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_text.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_read_highlights.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

import '../../support/cac_camera_harness.dart';

void main() {
  const tuning = CacScanTuning();
  const dodId = 'DoD ID Number 1087987498';

  RecognizedText recognized(List<String> lines,
          {double? confidence, Map<String, Set<int>> doubted = const {}}) =>
      RecognizedText.fromJson(CacCameraHarness.recognized(lines,
          confidence: confidence, doubted: doubted));

  group('the lines of a frame', () {
    test('keep what ML Kit is confident of, with where each sat', () {
      final text = CacFrameText.of(recognized(['NAME', 'SMITH, JOHN A']),
          tuning: tuning, checkDigits: false);
      expect(text.lines, ['NAME', 'SMITH, JOHN A']);
      expect(text.boxes.first, const Rect.fromLTRB(10, 10, 100, 30));
      expect(text.dropped, 0);
      expect(text.lowestConfidence, isNull);
    });

    test('drop lines ML Kit doubts, counting them', () {
      final text = CacFrameText.of(recognized([dodId], confidence: 0.2),
          tuning: tuning, checkDigits: false);
      expect(text.lines, isEmpty);
      expect(text.dropped, 1);
    });

    test('drop a line with a doubtful digit only when asked to', () {
      final shaky = recognized([
        dodId
      ], doubted: {
        dodId: {18}
      });
      final checked = CacFrameText.of(shaky, tuning: tuning, checkDigits: true);
      expect(checked.lines, isEmpty);
      expect(checked.doubtfulDigits, 1);
      expect(CacFrameText.of(shaky, tuning: tuning, checkDigits: false).lines,
          [dodId]);
    });

    test('track the least confident line kept', () {
      final text = CacFrameText.of(recognized([dodId], confidence: 0.7),
          tuning: tuning, checkDigits: true);
      expect(text.lowestConfidence, 0.7);
    });
  });

  group('outlines', () {
    final text = CacFrameText.of(recognized(['RANK', dodId]),
        tuning: tuning, checkDigits: false);

    test('fall on the barcode and the line holding the reading', () {
      final rects = cacReadHighlights(
        name: null,
        dodId: '1087987498',
        text: text,
        barcodeBoxes: [const Rect.fromLTRB(0, 0, 20, 40)],
        metadata: InputImageMetadata(
          size: const Size(400, 200),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 400,
        ),
      );
      expect(rects, [
        const Rect.fromLTRB(0, 0, 0.05, 0.2),
        const Rect.fromLTRB(0.025, 0.05, 0.25, 0.15),
      ]);
    });

    test('measure a sideways crop upright', () {
      final rects = cacReadHighlights(
        name: (firstName: 'JOHN', lastName: 'Rank'),
        dodId: null,
        text: text,
        barcodeBoxes: const [],
        metadata: InputImageMetadata(
          size: const Size(200, 400),
          rotation: InputImageRotation.rotation90deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 200,
        ),
      );
      expect(rects, [const Rect.fromLTRB(0.025, 0.05, 0.25, 0.15)]);
    });
  });
}
