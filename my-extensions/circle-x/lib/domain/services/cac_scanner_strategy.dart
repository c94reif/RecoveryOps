import 'package:circle_x/domain/entities/cac_scan.dart';

abstract class CacScannerStrategy {
  Future<bool> isAvailable();

  Future<CacCapture> capture();

  Future<void> cancel();
}
