import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

class CacMetering {
  final CameraController camera;
  final CacScanTuning tuning;
  bool _held = false;
  bool _dimmed = false;
  int _softFrames = 0;

  CacMetering(this.camera, this.tuning);

  bool get isHeld => _held;

  Future<void> focusAt(Offset point) {
    _held = false;
    _softFrames = 0;
    return _attempt('camera metering', [
      () => camera.setFocusMode(FocusMode.auto),
      () => camera.setExposureMode(ExposureMode.auto),
      if (camera.value.focusPointSupported) () => camera.setFocusPoint(point),
      if (camera.value.exposurePointSupported)
        () => camera.setExposurePoint(point),
    ]);
  }

  Future<void> hold() async {
    if (_held) return;
    _held = true;
    await _attempt('camera lock', [
      () => camera.setFocusMode(FocusMode.locked),
      () => camera.setExposureMode(ExposureMode.locked),
    ]);
  }

  bool softFrame() => _held && ++_softFrames >= tuning.softFramesBeforeRefocus;

  void sharpFrame() => _softFrames = 0;

  void dimForGlare() {
    if (_dimmed) return;
    _dimmed = true;
    unawaited(_attempt('exposure offset', [
      () async {
        final floor = await camera.getMinExposureOffset();
        await camera
            .setExposureOffset(math.max(floor, tuning.glareExposureOffset));
      },
    ]));
  }

  Future<bool> torch(bool on) async {
    try {
      await camera.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      return true;
    } catch (error) {
      debugPrint('[CacOcr] torch unavailable: $error');
      return false;
    }
  }

  static Future<void> _attempt(
      String what, List<Future<void> Function()> operations) async {
    for (final operation in operations) {
      try {
        await operation();
      } catch (error) {
        debugPrint('[CacOcr] $what unavailable: $error');
      }
    }
  }
}
