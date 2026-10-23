import 'package:cac_ocr/src/domain/cac_card_dates.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';
import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_scan.dart';

class ParseDodId {
  final DateTime Function() now;

  const ParseDodId([this.now = _systemNow]);

  static DateTime _systemNow() => DateTime.now().toUtc();

  static DateTime? _plausible(DateTime? expiresOn, DateTime now) =>
      expiresOn != null &&
              expiresOn.isAfter(now.add(CacCardDates.longestValidity))
          ? null
          : expiresOn;

  CacScan call(String raw,
      {CacName? name, String rank = '', DateTime? expiresOn}) {
    final digits = raw.trim().replaceAll(RegExp(r'[ \t\u00a0-]+'), '');
    if (!DodId.isValid(digits)) {
      return const CacScan.rejected(CacRejection.notACac);
    }
    final scannedAt = now().toUtc();
    final identity = CacIdentity(
      dodId: digits,
      firstName: name?.firstName ?? '',
      lastName: name?.lastName ?? '',
      rank: rank,
      cardExpiresOn: _plausible(expiresOn, scannedAt),
      verifiedAt: scannedAt,
    );
    return CacScan.of(identity);
  }
}
