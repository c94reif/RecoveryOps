String cacBarcode({
  String version = 'N',
  String securityId = 'TP7S7C',
  String designatorType = 'S',
  String dodId = '10DINPA',
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
    ..write(_fixed(dodId, 7))
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

  if (version == 'N') record.write(_fixed(middleInitial, 1));

  return record.toString();
}

String _fixed(String value, int width) =>
    value.length >= width ? value.substring(0, width) : value.padRight(width);
