import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

/// Reads the Soldier closing a PMCS out off the front of their CAC — the tall
/// PDF417 beside the gold chip, never the gate strip on the back.
///
/// Two halves that fail differently: the camera can come back with nothing,
/// and what it does come back with can turn out not to be a CAC. Both land as
/// a [CacScan] the operator can act on, because the difference decides what
/// they do next — shoot the card again, or turn it over and find a current
/// one.
class VerifyOperatorIdentity {
  final CacScannerStrategy scanner;
  final ParseCacBarcode parseBarcode;

  const VerifyOperatorIdentity({
    required this.scanner,
    required this.parseBarcode,
  });

  Future<CacScan> call() async {
    final capture = await scanner.capture();

    final barcode = capture.barcode;
    if (barcode == null) {
      return CacScan.rejected(capture.rejection ?? CacRejection.noCodeFound);
    }

    return parseBarcode(barcode);
  }
}
