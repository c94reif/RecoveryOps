import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/clock.dart';

/// Turns the PDF417 off the front of a CAC into the Soldier who is signing.
///
/// Format is DMDC *DoD ID Bar Code Formats*, SDK v7.5.0 (Sep 2012), §2.2.
/// Fixed-width ASCII, no delimiters, two versions in circulation:
///
/// ```
/// version 'N' (89 chars)            version '1' (88 chars)
/// [0]     version code              same, but '1'
/// [1:7]   PDI / card security id     …
/// [7]     person designator type      …
/// [8:15]  EDIPI (DoD ID number)       …
/// [15:35] first name                  …
/// [35:61] surname                     …
/// [61:65] date of birth               …
/// [65]    personnel category          …
/// [66]    branch                      …
/// [67:69] entitlement condition       …
/// [69:75] rank                        …
/// [75:77] pay plan code               …
/// [77:79] pay plan grade              …
/// [79:83] card issue date             …
/// [83:87] card expiration date        …
/// [87]    card instance id            …
/// [88]    middle initial             absent
/// ```
///
/// Numeric fields are packed base-32 over `0-9A-V`; dates are that same
/// packing over a day count from 1 January 1000.
///
/// Date of birth, the entitlement condition, and the pay-plan pair are read
/// far enough to validate the record and then discarded — see [CacIdentity]
/// for why. The card security identifier is never returned at all: on a card
/// issued before 1 December 2012 that field is the cardholder's SSN, which is
/// why such a card is refused outright rather than parsed around.
///
/// The Code 39 strip on the *back* of the card is the same spec's Table 2 and
/// is recognised here too — not to read, only to say so. It carries an EDIPI
/// and nothing else a signature block needs, so letting it through would put
/// `DoD ID 1087987498` on a 5988-E with no way for a maintainer to tell it
/// apart from a real read.
///
/// A scan proves the operator is holding the card. It is not authentication —
/// the barcode is unsigned cleartext that anyone can reprint — so this is a
/// strong attribution of who closed a PMCS out, not a cryptographic
/// signature. Binding that hard needs the CAC's PKI certificates, which the
/// host does not expose.
class ParseCacBarcode {
  final Clock clock;

  const ParseCacBarcode(this.clock);

  /// The day the base-32 date fields count from.
  static final DateTime dateEpoch = DateTime.utc(1000, 1, 1);

  /// From 1 December 2012 the card security identifier is `999` followed by a
  /// per-card serial. Anything below that is a real SSN in that field.
  static const int lowestPostSsnSecurityId = 999000000;

  /// DEERS has never issued a DoD ID number outside this range. A value
  /// outside it means the fields are misaligned, not that a Soldier has an
  /// odd id — and a misaligned record would name the wrong Soldier.
  static const int lowestEdipi = 1000000000;
  static const int highestEdipi = 9999999999;

  CacScan call(String raw) {
    // Many readers hand back the Code 39 start/stop sentinels; the PDF417
    // never carries them, but a stray one must not shift every field by one.
    // Control characters go the same way — a reader that appends a carriage
    // return must not lengthen the record.
    final cleaned =
        raw.replaceAll('*', '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Leading whitespace is always padding — field 0 is the version character
    // and can never be a space. Trailing whitespace is not so simple: the last
    // field of both layouts is a single character that is legitimately blank
    // on a real card (the middle initial on a version-`N` record for a Soldier
    // with no middle name, the card instance on a version-`1`), so a blanket
    // `trim()` eats it and shortens an 89 to an 88 that matches neither
    // layout. That refused every such Soldier as `notACac`, and unrecoverably
    // — the message tells them to re-aim at a card they are already holding
    // correctly, so they could only ever close the PMCS out unverified.
    //
    // So the right edge is only trimmed when what is in hand is not already a
    // whole record. A record that arrives with trailing padding AND a blank
    // final field is genuinely undecidable, and that is the case given up on.
    final led = cleaned.trimLeft();
    final text =
        (led.length == 88 || led.length == 89) ? led : led.trimRight();

    // Tested before the front-of-card gate below, which would otherwise call
    // the back of the card `notACac` and send a Soldier looking for a card
    // already in their hand.
    //
    // The back is now the side the operator is asked for, and its strip
    // carries the one thing the Android path also reads off it: the DoD ID
    // number. So a Code 39 read is a signature by number — the same identity
    // an OCR read produces — rather than the wrong side of the card.
    if (_isCacCode39(text)) {
      return CacScan.verified(CacIdentity(
        edipi: _base32(text, 8, 15)!.toString().padLeft(10, '0'),
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

    final securityId = _base32(text, 1, 7);
    final edipi = _base32(text, 8, 15);
    if (securityId == null || edipi == null) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    // Refused before anything is read off the card, and deliberately without
    // reporting the value anywhere — on one of these the field just decoded
    // is an SSN.
    if (securityId < lowestPostSsnSecurityId) {
      return const CacScan.rejected(CacRejection.legacySsnCard);
    }

    if (!_isPlausibleEdipi(edipi)) {
      return const CacScan.rejected(CacRejection.notACac);
    }

    // A CAC is good *through* the date printed on it, and the field decodes to
    // midnight at the start of that day. Comparing against it directly would
    // deadline a card one second after midnight on its last valid day and —
    // because `expired` is not worth retrying — steer that Soldier straight to
    // an unverified submission with a perfectly good card in their hand.
    // Refused only once the whole expiry day is behind them.
    final expiresOn = _date(text, 83, 87);
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

  /// Whether [text] is the Code 39 strip off the *back* of the card.
  ///
  /// Same DMDC spec, Table 2: 18 fixed-width characters — version `1`, the
  /// Person Designator Identifier (6), its type (1), the EDIPI (7), the
  /// personnel category (1), the branch (1), the card instance (1). No name,
  /// no rank, no dates, which is why the answer is a rejection and never an
  /// identity.
  ///
  /// Every field is checked, not just the length. A motor pool is full of
  /// 18-character barcodes — tool crib tags, part labels, container
  /// placards — and matching one of those would tell a Soldier to turn over a
  /// card they are already holding the right way round. Failing to recognise
  /// a real one only costs the vaguer `notACac`, so the check leans tight.
  static bool _isCacCode39(String text) {
    if (text.length != 18 || text[0] != '1') return false;

    // Validated, never bound to a name: on a pre-2012 card this field is an
    // SSN, and the front-of-card path refuses those for the same reason.
    if (_base32(text, 1, 7) == null) return false;

    // Person designator type, personnel category and branch are letter codes
    // on every card DMDC has issued. A digit in any of them means this is
    // some other 18-character barcode.
    if (!_isUpperAlpha(text, 7) ||
        !_isUpperAlpha(text, 15) ||
        !_isUpperAlpha(text, 16)) {
      return false;
    }

    // The card instance is machine-generated and may be either.
    if (!_isUpperAlpha(text, 17) && !_isDigit(text, 17)) return false;

    return _isPlausibleEdipi(_base32(text, 8, 15));
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

  /// Base-32 over `0-9A-V`, most significant character first. Null on any
  /// character outside the alphabet — that is misalignment, and a silently
  /// coerced value would put the wrong Soldier's name on a 5988-E.
  static int? _base32(String text, int start, int end) {
    var value = 0;
    for (var i = start; i < end; i++) {
      final code = text.codeUnitAt(i);
      final digit = switch (code) {
        >= 0x30 && <= 0x39 => code - 0x30, // '0'-'9'
        >= 0x41 && <= 0x56 => code - 0x41 + 10, // 'A'-'V'
        _ => null,
      };
      if (digit == null) return null;
      value = value * 32 + digit;
    }
    return value;
  }

  /// A four-character base-32 count of days from [dateEpoch]. Dart's
  /// [DateTime] is proleptic Gregorian, which is the calendar the spec counts
  /// on, so the day count adds straight on.
  static DateTime? _date(String text, int start, int end) {
    final days = _base32(text, start, end);
    if (days == null) return null;
    return dateEpoch.add(Duration(days: days));
  }
}
