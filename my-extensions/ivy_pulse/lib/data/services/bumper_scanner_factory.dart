import 'package:ivy_pulse/domain/services/bumper_scanner_strategy.dart';
import 'package:ivy_pulse/data/services/unavailable_bumper_scanner.dart'
    if (dart.library.io) 'package:ivy_pulse/data/services/android_bumper_scanner.dart'
    as platform;

BumperScannerStrategy createBumperScanner() => platform.createBumperScanner();
