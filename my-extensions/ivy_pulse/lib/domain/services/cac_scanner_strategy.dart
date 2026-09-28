import 'package:ivy_pulse/domain/entities/cac_scan.dart';

abstract class CacScannerStrategy {
  Future<bool> isAvailable();

  Future<CacCapture> capture();

  Future<void> cancel();
}
