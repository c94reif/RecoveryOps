import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

import 'package:ivy_pulse/data/services/unavailable_cac_scanner.dart'
    if (dart.library.js_interop) 'package:ivy_pulse/data/services/web_cac_scanner.dart'
    if (dart.library.io) 'package:ivy_pulse/data/services/android_cac_scanner.dart'
    as platform;

CacScannerStrategy createCacScanner() => platform.createCacScanner();
