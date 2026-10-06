import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

final _digit = RegExp(r'^[0-9]$');

class CacFrameText {
  final List<String> lines;

  final List<Rect> boxes;
  final int dropped;
  final int doubtfulDigits;
  final double? lowestConfidence;

  const CacFrameText._(this.lines, this.boxes,
      {required this.dropped,
      required this.doubtfulDigits,
      required this.lowestConfidence});

  factory CacFrameText.of(RecognizedText result,
      {required CacScanTuning tuning, required bool checkDigits}) {
    final lines = <String>[];
    final boxes = <Rect>[];
    var dropped = 0;
    var doubtful = 0;
    double? lowest;
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final confidence = line.confidence;
        final doubted = checkDigits ? _doubtfulDigits(line, tuning) : 0;
        if ((confidence ?? 1) < tuning.minLineConfidence || doubted > 0) {
          doubtful += doubted;
          dropped++;
          continue;
        }
        if (confidence != null) {
          lowest = lowest == null ? confidence : math.min(lowest, confidence);
        }
        lines.add(line.text);
        boxes.add(line.boundingBox);
      }
    }
    return CacFrameText._(lines, boxes,
        dropped: dropped, doubtfulDigits: doubtful, lowestConfidence: lowest);
  }

  static int _doubtfulDigits(TextLine line, CacScanTuning tuning) => [
        for (final word in line.elements)
          for (final symbol in word.symbols)
            if ((symbol.confidence ?? 1) < tuning.minDigitConfidence &&
                _digit.hasMatch(symbol.text))
              symbol,
      ].length;
}
