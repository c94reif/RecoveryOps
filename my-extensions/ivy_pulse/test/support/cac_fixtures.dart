/// Builds a CAC front-barcode record field by field, at the exact widths the
/// DMDC SDK v7.5.0 §2.2 lays down.
///
/// Assembled rather than written out as a literal so a fixture can never
/// drift a character and quietly shift every field after it — the failure
/// mode that would make the parser's tests agree with a bug.
///
/// Base-32 values used below, all verified against DMDC's own published
/// samples: `10DINPA` = EDIPI 1087987498, `TP7S7C` = security id 999551212
/// (post-2012), `ATJ1` = 1980-02-18, `BER2` = 2028-06-30, `BBQH` =
/// 2020-01-15, `BCMI` = 2022-06-30.
String cacBarcode({
  String version = 'N',
  String securityId = 'TP7S7C',
  String designatorType = 'S',
  String edipi = '10DINPA',
  String firstName = 'JOHN',
  String lastName = 'SMITH',
  String dateOfBirth = 'ATJ1',
  String category = 'A',
  String branch = 'A',
  String entitlement = '01',
  String rank = 'SGT',
  String payPlan = 'ME',
  String grade = '05',
  String issued = 'BCMI',
  String expires = 'BER2',
  String cardInstance = 'K',
  String middleInitial = 'A',
}) {
  final record = StringBuffer()
    ..write(_fixed(version, 1))
    ..write(_fixed(securityId, 6))
    ..write(_fixed(designatorType, 1))
    ..write(_fixed(edipi, 7))
    ..write(_fixed(firstName, 20))
    ..write(_fixed(lastName, 26))
    ..write(_fixed(dateOfBirth, 4))
    ..write(_fixed(category, 1))
    ..write(_fixed(branch, 1))
    ..write(_fixed(entitlement, 2))
    ..write(_fixed(rank, 6))
    ..write(_fixed(payPlan, 2))
    ..write(_fixed(grade, 2))
    ..write(_fixed(issued, 4))
    ..write(_fixed(expires, 4))
    ..write(_fixed(cardInstance, 1));

  // Version '1' is the same record minus the trailing initial — 88 characters
  // against 89.
  if (version == 'N') record.write(_fixed(middleInitial, 1));

  return record.toString();
}

/// Text fields are space-padded on the right; over-long input is truncated the
/// way the card issuer truncates it.
String _fixed(String value, int width) =>
    value.length >= width ? value.substring(0, width) : value.padRight(width);
