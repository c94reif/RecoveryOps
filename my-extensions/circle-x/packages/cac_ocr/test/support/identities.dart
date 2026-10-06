import 'package:cac_ocr/src/domain/cac_identity.dart';

/// A Soldier as the parser would hand one back, for tests that need an
/// identity without going through a barcode.
CacIdentity buildIdentity({
  String dodId = '1087987498',
  String firstName = 'JOHN',
  String lastName = 'SMITH',
  String middleInitial = 'A',
  String rank = 'SGT',
  String branchCode = 'A',
  String categoryCode = 'A',
  DateTime? cardExpiresOn,
  String cardInstance = 'K',
  DateTime? verifiedAt,
}) {
  return CacIdentity(
    dodId: dodId,
    firstName: firstName,
    lastName: lastName,
    middleInitial: middleInitial,
    rank: rank,
    branchCode: branchCode,
    categoryCode: categoryCode,
    cardExpiresOn: cardExpiresOn ?? DateTime.utc(2028, 6, 30),
    cardInstance: cardInstance,
    verifiedAt: verifiedAt ?? DateTime.utc(2026, 3, 24, 9),
  );
}
