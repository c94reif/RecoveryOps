import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_gate.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

void main() {
  const tuning = CacScanTuning();
  CacFrameGate gate() => CacFrameGate(tuning);

  test('a frame well under the recent sharpest is blurred', () {
    final frames = gate();
    expect(frames.judge((sharpness: 100, glare: 0)), isNull);
    // The sharpest fades to 90 first, so the bar is 54.
    expect(frames.judge((sharpness: 50, glare: 0)), CacFrameSkip.blur);
    expect(frames.judge((sharpness: 60, glare: 0)), isNull);
  });

  test('the sharpest frame is forgotten, so a moved card can read again', () {
    final frames = gate()..judge((sharpness: 100, glare: 0));
    expect(frames.sharpest, 100);
    for (var frame = 0; frame < 5; frame++) {
      frames.judge((sharpness: 0, glare: 0));
    }
    expect(frames.sharpest, closeTo(100 * 0.59049, 1e-9));
    expect(frames.judge((sharpness: 40, glare: 0)), isNull);
  });

  test('glare is coached past one share and skipped past another', () {
    final frames = gate();
    const some = (sharpness: 100.0, glare: 0.2);
    const most = (sharpness: 100.0, glare: 0.5);
    expect(frames.judge(some), isNull);
    expect(frames.isGlary(some), isTrue);
    expect(frames.judge(most), CacFrameSkip.glare);
    expect(frames.isGlary((sharpness: 100, glare: 0.1)), isFalse);
  });

  test('the thresholds are the tuning, not constants', () {
    final strict = CacFrameGate(const CacScanTuning(blurRatio: 0.9))
      ..judge((sharpness: 100, glare: 0));
    expect(strict.judge((sharpness: 80, glare: 0)), CacFrameSkip.blur);
  });
}
