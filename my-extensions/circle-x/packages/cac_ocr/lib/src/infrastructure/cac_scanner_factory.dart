import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

import 'package:cac_ocr/src/infrastructure/unavailable_cac_scanner.dart'
    if (dart.library.js_interop) 'package:cac_ocr/src/infrastructure/web/web_cac_scanner.dart'
    if (dart.library.io) 'package:cac_ocr/src/infrastructure/android/android_cac_scanner.dart'
    as platform;

CacScannerStrategy createCacScanner({
  Duration captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
  CacSides sides = CacSides.frontAndBack,
  CacScanDiagnostics? diagnostics,
  CacScanTuning tuning = const CacScanTuning(),
}) =>
    platform.createCacScanner(
        captureTimeout: captureTimeout,
        sides: sides,
        diagnostics: diagnostics,
        tuning: tuning);
