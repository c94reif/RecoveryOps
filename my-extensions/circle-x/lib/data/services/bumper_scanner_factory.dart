import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';
import 'package:circle_x/data/services/unavailable_bumper_scanner.dart'
    if (dart.library.io) 'package:circle_x/data/services/android_bumper_scanner.dart'
    as platform;

BumperScannerStrategy createBumperScanner() => platform.createBumperScanner();
