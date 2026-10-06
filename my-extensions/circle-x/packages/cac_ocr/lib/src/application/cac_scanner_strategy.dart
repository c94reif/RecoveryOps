import 'package:cac_ocr/src/domain/cac_capture.dart';

abstract interface class CacScannerStrategy {
  static const Duration defaultCaptureTimeout = Duration(seconds: 120);

  Future<bool> isAvailable();

  Future<CacCapture> capture();

  Future<void> cancel();
}
