import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

/// Stands in wherever there is no camera to reach.
///
/// That is two places. Tests run on the Dart VM, where there is no DOM. And
/// the native build Anduril compiles this source into has no WebView either —
/// once `le_sdk` grows a camera capability, a real scanner drops in behind
/// [CacScannerStrategy] and nothing above this line changes.
///
/// It refuses rather than pretends. An operator told "no camera on this
/// device" can close the PMCS out unverified and get on with the mission; one
/// handed a scanner that silently never reads anything cannot.
class UnavailableCacScanner implements CacScannerStrategy {
  const UnavailableCacScanner();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<CacCapture> capture() async =>
      const CacCapture.failed(CacRejection.noCamera);

  /// A no-op, and correctly so: [capture] refuses before it reaches a camera,
  /// so there has never been anything in flight to abandon.
  @override
  Future<void> cancel() async {}
}

CacScannerStrategy createCacScanner() => const UnavailableCacScanner();
