import 'package:circle_x/domain/services/cac_scanner_strategy.dart';

import 'package:circle_x/data/services/unavailable_cac_scanner.dart'
    if (dart.library.js_interop) 'package:circle_x/data/services/web_cac_scanner.dart'
    if (dart.library.io) 'package:circle_x/data/services/android_cac_scanner.dart'
    as platform;

CacScannerStrategy createCacScanner() => platform.createCacScanner();
