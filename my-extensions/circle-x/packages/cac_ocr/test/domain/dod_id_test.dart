import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';

void main() {
  test('a stored DoD ID is ten digits with no leading zero', () {
    expect(DodId.isValid('1087987498'), isTrue);
    expect(DodId.isValid('0087987498'), isFalse);
    expect(DodId.isValid('108798749'), isFalse);
    expect(DodId.isValid('1087 987 498'), isFalse);
    expect(DodId.isValid(1087987498), isFalse);
    expect(DodId.isValid(null), isFalse);
  });

  test('DEERS issues numbers from 1000000000 up', () {
    expect(DodId.isIssued(DodId.lowest), isTrue);
    expect(DodId.isIssued(DodId.highest), isTrue);
    expect(DodId.isIssued(999999999), isFalse);
    expect(DodId.isIssued(1), isFalse);
  });

  test('typed spacing and punctuation fall away', () {
    expect(DodId.digitsOf(' 1087-987 498 '), '1087987498');
  });
}
