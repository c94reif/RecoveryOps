import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_scan.dart';

class ParseCacBarcode {
  final DateTime Function() now;

  const ParseCacBarcode([this.now = _systemNow]);

  static DateTime _systemNow() => DateTime.now().toUtc();

  static final DateTime dateEpoch = DateTime.utc(1000, 1, 1);

  static const int lowestPostSsnSecurityId = 999000000;

  static bool isFrontRecord(String raw) {
    final text = _record(raw);
    return (text.length == 89 && text[0] == 'N') ||
        (text.length == 88 && text[0] == '1');
  }

  static String? dodIdFromCode39(String raw) {
    final text = _record(raw);
    return _isCacCode39(text)
        ? _decodeBase32Field(text, 8, 15)!.toString().padLeft(10, '0')
        : null;
  }

  static String _record(String raw) {
    final sanitizedText =
        raw.replaceAll('*', '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    final leftTrimmedText = sanitizedText.trimLeft();
    return (leftTrimmedText.length == 88 || leftTrimmedText.length == 89)
        ? leftTrimmedText
        : leftTrimmedText.trimRight();
  }

  CacScan call(String raw) {
    final text = _record(raw);

    if (_isCacCode39(text)) {
      return CacScan.verified(CacIdentity(
        dodId: _decodeBase32Field(text, 8, 15)!.toString().padLeft(10, '0'),
        firstName: '',
        lastName: '',
        verifiedAt: now().toUtc(),
      ));
    }

    final version = text.isEmpty ? '' : text[0];
    final hasMiddleInitial = text.length == 89 && version == 'N';
    final isLegacyLayout = text.length == 88 && version == '1';
    if (!hasMiddleInitial && !isLegacyLayout) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    final securityId = _decodeBase32Field(text, 1, 7);
    final dodId = _decodeBase32Field(text, 8, 15);
    if (securityId == null || dodId == null) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    if (securityId < lowestPostSsnSecurityId) {
      return const CacScan.rejected(CacRejection.legacySsnCard);
    }

    if (!DodId.isIssued(dodId)) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    final identity = CacIdentity(
      dodId: dodId.toString().padLeft(10, '0'),
      firstName: text.substring(15, 35).trimRight(),
      lastName: text.substring(35, 61).trimRight(),
      middleInitial: hasMiddleInitial ? text.substring(88, 89).trim() : '',
      rank: text.substring(69, 75).trimRight(),
      branchCode: text.substring(66, 67).trim(),
      categoryCode: text.substring(65, 66).trim(),
      cardExpiresOn: _decodeDateField(text, 83, 87),
      cardInstance: text.substring(87, 88).trim(),
      verifiedAt: now().toUtc(),
    );
    return CacScan.of(identity);
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

    final dodId = _decodeBase32Field(text, 8, 15);
    return dodId != null && DodId.isIssued(dodId);
  }

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
