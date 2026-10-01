import 'package:circle_x/domain/entities/cac_identity.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/clock.dart';

class ParseCacBarcode {
  final Clock clock;

  const ParseCacBarcode(this.clock);

  static final DateTime dateEpoch = DateTime.utc(1000, 1, 1);

  static const int lowestPostSsnSecurityId = 999000000;

  static const int lowestEdipi = 1000000000;
  static const int highestEdipi = 9999999999;

  CacScan call(String raw) {
    final sanitizedText =
        raw.replaceAll('*', '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    final leftTrimmedText = sanitizedText.trimLeft();
    final text = (leftTrimmedText.length == 88 || leftTrimmedText.length == 89)
        ? leftTrimmedText
        : leftTrimmedText.trimRight();

    if (_isCacCode39(text)) {
      return CacScan.verified(CacIdentity(
        edipi: _decodeBase32Field(text, 8, 15)!.toString().padLeft(10, '0'),
        firstName: '',
        lastName: '',
        verifiedAt: clock.nowUtc(),
      ));
    }

    final version = text.isEmpty ? '' : text[0];
    final hasMiddleInitial = text.length == 89 && version == 'N';
    final isLegacyLayout = text.length == 88 && version == '1';
    if (!hasMiddleInitial && !isLegacyLayout) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    final securityId = _decodeBase32Field(text, 1, 7);
    final edipi = _decodeBase32Field(text, 8, 15);
    if (securityId == null || edipi == null) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    if (securityId < lowestPostSsnSecurityId) {
      return const CacScan.rejected(CacRejection.legacySsnCard);
    }

    if (!_isPlausibleEdipi(edipi)) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    final expiresOn = _decodeDateField(text, 83, 87);
    if (expiresOn != null &&
        !expiresOn.add(const Duration(days: 1)).isAfter(clock.nowUtc())) {
      return const CacScan.rejected(CacRejection.expired);
    }

    return CacScan.verified(CacIdentity(
      edipi: edipi.toString().padLeft(10, '0'),
      firstName: text.substring(15, 35).trimRight(),
      lastName: text.substring(35, 61).trimRight(),
      middleInitial: hasMiddleInitial ? text.substring(88, 89).trim() : '',
      rank: text.substring(69, 75).trimRight(),
      branchCode: text.substring(66, 67).trim(),
      categoryCode: text.substring(65, 66).trim(),
      cardExpiresOn: expiresOn,
      cardInstance: text.substring(87, 88).trim(),
      verifiedAt: clock.nowUtc(),
    ));
  }

  static bool _isCacCode39(String text) {
    if (text.length != 18 || text[0] != '1') return false;

    if (_decodeBase32Field(text, 1, 7) == null) return false;

    if (!_isUpperAlpha(text, 7) ||
        !_isUpperAlpha(text, 15) ||
        !_isUpperAlpha(text, 16)) {
      return false;
    }

    if (!_isUpperAlpha(text, 17) && !_isDigit(text, 17)) return false;

    return _isPlausibleEdipi(_decodeBase32Field(text, 8, 15));
  }

  static bool _isPlausibleEdipi(int? value) =>
      value != null && value >= lowestEdipi && value <= highestEdipi;

  static bool _isUpperAlpha(String text, int index) {
    final code = text.codeUnitAt(index);
    return code >= 0x41 && code <= 0x5A;
  }

  static bool _isDigit(String text, int index) {
    final code = text.codeUnitAt(index);
    return code >= 0x30 && code <= 0x39;
  }

  static int? _decodeBase32Field(String text, int start, int end) {
    var value = 0;
    for (var characterIndex = start; characterIndex < end; characterIndex++) {
      final code = text.codeUnitAt(characterIndex);
      final digit = switch (code) {
        >= 0x30 && <= 0x39 => code - 0x30,
        >= 0x41 && <= 0x56 => code - 0x41 + 10,
        _ => null,
      };
      if (digit == null) return null;
      value = value * 32 + digit;
    }
    return value;
  }

  static DateTime? _decodeDateField(String text, int start, int end) {
    final days = _decodeBase32Field(text, start, end);
    if (days == null) return null;
    return dateEpoch.add(Duration(days: days));
  }
}
