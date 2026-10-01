import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:circle_x/domain/usecases/identity/parse_dod_id.dart';

class VerifyOperatorIdentity {
  final CacScannerStrategy scanner;
  final ParseCacBarcode parseBarcode;
  final ParseDodId parseDodId;

  VerifyOperatorIdentity({
    required this.scanner,
    required this.parseBarcode,
    ParseDodId? parseDodId,
  }) : parseDodId = parseDodId ?? ParseDodId(parseBarcode.clock);

  static final RegExp _dodIdShape = RegExp(r'^\d{10}$');

  Future<CacScan> call() async {
    final capture = await scanner.capture();

    final read = capture.barcode;
    if (read == null) {
      return CacScan.rejected(capture.rejection ?? CacRejection.noCodeFound);
    }

    final trimmed = read.trim();
    if (_dodIdShape.hasMatch(trimmed)) {
      return parseDodId(trimmed, name: capture.name);
    }
    return parseBarcode(read);
  }
}
