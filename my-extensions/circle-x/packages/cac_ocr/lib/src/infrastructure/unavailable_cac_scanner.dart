import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

class UnavailableCacScanner implements CacScannerStrategy {
  const UnavailableCacScanner();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<CacCapture> capture() async =>
      const CacCapture.failed(CacRejection.noCamera);

  @override
  Future<void> cancel() async {}
}

CacScannerStrategy createCacScanner({
  Duration captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
  CacSides sides = CacSides.frontAndBack,
  CacScanDiagnostics? diagnostics,
  CacScanTuning tuning = const CacScanTuning(),
}) =>
    const UnavailableCacScanner();
