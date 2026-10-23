import 'package:circle_x/domain/vehicle/services/bumper_scanner_strategy.dart';
import 'package:circle_x/data/services/vehicle/unavailable_bumper_scanner.dart'
    if (dart.library.io) 'package:circle_x/data/services/vehicle/android_bumper_scanner.dart'
    as platform;

BumperScannerStrategy createBumperScanner() => platform.createBumperScanner();
