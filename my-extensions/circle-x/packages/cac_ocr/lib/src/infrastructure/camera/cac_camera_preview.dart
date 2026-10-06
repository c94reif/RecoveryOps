import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';

abstract interface class CacCameraPreview {
  CacSides get sides;

  ValueListenable<CameraController?> get preview;

  ValueListenable<CacGuidance> get guidance;

  ValueListenable<CacScanSide> get side;

  Future<void> focusAt(Offset point);
}
