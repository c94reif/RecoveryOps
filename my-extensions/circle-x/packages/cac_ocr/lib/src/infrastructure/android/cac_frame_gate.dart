import 'dart:math' as math;

import 'package:cac_ocr/src/infrastructure/android/cac_frame_quality.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

class CacFrameGate {
  final CacScanTuning tuning;
  double _sharpest = 0;

  CacFrameGate(this.tuning);

  double get sharpest => _sharpest;

  CacFrameSkip? judge(CacFrameQuality quality) {
    _sharpest = math.max(quality.sharpness, _sharpest * tuning.sharpnessDecay);
    if (quality.glare >= tuning.glareToSkip) return CacFrameSkip.glare;
    if (quality.sharpness < _sharpest * tuning.blurRatio) {
      return CacFrameSkip.blur;
    }
    return null;
  }

  bool isGlary(CacFrameQuality quality) => quality.glare >= tuning.glareToCoach;
}
