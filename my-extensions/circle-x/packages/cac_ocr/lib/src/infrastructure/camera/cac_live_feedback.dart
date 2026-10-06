import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';

abstract interface class CacLiveFeedback {
  ValueListenable<List<Rect>> get highlights;

  ValueListenable<bool?> get torch;
  Future<void> setTorch(bool on);

  CacScanDiagnostics? get diagnostics;
}
