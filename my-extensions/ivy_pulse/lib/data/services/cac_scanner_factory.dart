import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

// The web scanner reaches for `dart:js_interop`, which does not exist on the
// Dart VM, so it can only ever be named behind this conditional — the same
// shape `createQueueWorker` uses for the isolate-versus-timer split.
import 'package:ivy_pulse/data/services/unavailable_cac_scanner.dart'
    if (dart.library.js_interop) 'package:ivy_pulse/data/services/web_cac_scanner.dart'
    as platform;

/// Picks the CAC scanner the platform can actually run.
CacScannerStrategy createCacScanner() => platform.createCacScanner();
