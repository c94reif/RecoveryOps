import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_scan.dart';
import 'package:cac_ocr/src/domain/parse_cac_barcode.dart';
import 'package:cac_ocr/src/domain/parse_dod_id.dart';

/// Scans a card and says who it belongs to: the use case behind every
/// sign-off. A barcode is decoded here; fields the scanner read itself are
/// checked the same way, so every scanner's capture meets the same rules.
class VerifyOperatorIdentity {
  final CacScannerStrategy scanner;
  final ParseCacBarcode parseBarcode;
  final ParseDodId parseDodId;

  /// Accepts a card past its printed expiry date instead of refusing it. The
  /// identity still carries the date, so the verified card can say so.
  final bool allowExpired;

  VerifyOperatorIdentity({
    required this.scanner,
    required this.parseBarcode,
    ParseDodId? parseDodId,
    this.allowExpired = false,
  }) : parseDodId = parseDodId ?? ParseDodId(parseBarcode.now);

  Future<CacScan> call() async {
    final scan = switch (await scanner.capture()) {
      CacBarcodeCapture(:final raw) => parseBarcode(raw),
      CacFieldsCapture(
        :final dodId,
        :final name,
        :final rank,
        :final expiresOn
      ) =>
        parseDodId(dodId, name: name, rank: rank, expiresOn: expiresOn),
      CacFailedCapture(:final rejection) => CacScan.rejected(rejection),
    };
    return switch (scan.expiredCard) {
      final card? when allowExpired => CacScan.verified(card),
      _ => scan,
    };
  }
}
