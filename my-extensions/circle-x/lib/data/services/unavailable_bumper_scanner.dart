import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';

class UnavailableBumperScanner implements BumperScannerStrategy {
  @override
  bool get isSupported => false;
  @override
  Future<void> start() async => throw BumperScanFailure.unavailable;
  @override
  Future<List<String>> read() async => throw BumperScanFailure.unavailable;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

BumperScannerStrategy createBumperScanner() => UnavailableBumperScanner();
