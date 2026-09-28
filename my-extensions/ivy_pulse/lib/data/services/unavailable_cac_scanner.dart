import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

class UnavailableCacScanner implements CacScannerStrategy {
  const UnavailableCacScanner();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<CacCapture> capture() async =>
      const CacCapture.failed(CacRejection.noCamera);

  @override
  Future<void> cancel() async {}
}

CacScannerStrategy createCacScanner() => const UnavailableCacScanner();
