import 'package:flutter/foundation.dart';

@immutable
class CacScanTuning {
  final double minLineConfidence;

  final double minDigitConfidence;

  final double blurRatio;

  final double sharpnessDecay;

  final double glareToCoach;
  final double glareToSkip;

  final double glareExposureOffset;

  final int softFramesBeforeRefocus;

  final int unreadableFramesBeforeUpgrade;

  const CacScanTuning({
    this.minLineConfidence = 0.5,
    this.minDigitConfidence = 0.5,
    this.blurRatio = 0.6,
    this.sharpnessDecay = 0.9,
    this.glareToCoach = 0.15,
    this.glareToSkip = 0.35,
    this.glareExposureOffset = -1.0,
    this.softFramesBeforeRefocus = 3,
    this.unreadableFramesBeforeUpgrade = 12,
  });
}
