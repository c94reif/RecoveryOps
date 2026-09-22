import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_dod_id.dart';

/// Reads the operator's CAC and turns whatever the scanner handed back into
/// a Soldier — or into the reason it could not.
///
/// Two kinds of read arrive here. The Android scanner OCRs the back of the
/// card and hands over the ten-digit DoD ID number; the web scanner, kept
/// for development, decodes a barcode and hands over the raw record — 89
/// characters off the front, 18 off the back. They are told apart by shape
/// alone, which is unambiguous: no barcode record is ten characters long.
class VerifyOperatorIdentity {
  final CacScannerStrategy scanner;
  final ParseCacBarcode parseBarcode;
  final ParseDodId parseDodId;

  VerifyOperatorIdentity({
    required this.scanner,
    required this.parseBarcode,
    ParseDodId? parseDodId,
  }) : parseDodId = parseDodId ?? ParseDodId(parseBarcode.clock);

  /// Exactly ten digits — a DoD ID number read as text, not a barcode.
  static final RegExp _dodIdShape = RegExp(r'^\d{10}$');

  Future<CacScan> call() async {
    final capture = await scanner.capture();

    final read = capture.barcode;
    if (read == null) {
      return CacScan.rejected(capture.rejection ?? CacRejection.noCodeFound);
    }

    final trimmed = read.trim();
    if (_dodIdShape.hasMatch(trimmed)) return parseDodId(trimmed);
    return parseBarcode(read);
  }
}
