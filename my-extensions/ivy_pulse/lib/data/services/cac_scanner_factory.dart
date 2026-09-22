import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

// Each scanner reaches for something the other platform does not have: the
// web one for `dart:js_interop`, the Android one for `dart:io`, the camera
// and ML Kit. So each is named only behind its own conditional — the same
// shape `createQueueWorker` uses for the isolate-versus-timer split. Web is
// tested first because a web build reports neither `dart:io` nor a camera.
import 'package:ivy_pulse/data/services/unavailable_cac_scanner.dart'
    if (dart.library.js_interop) 'package:ivy_pulse/data/services/web_cac_scanner.dart'
    if (dart.library.io) 'package:ivy_pulse/data/services/android_cac_scanner.dart'
    as platform;

/// Picks the CAC scanner the platform can actually run: OCR of the back of
/// the card from a live preview on Android, the barcode photograph on the
/// web build kept for development, nothing anywhere else.
CacScannerStrategy createCacScanner() => platform.createCacScanner();
