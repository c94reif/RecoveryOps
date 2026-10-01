import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/usecases/identity/cac_ocr_session.dart';

void main() {
  const front = ['NAME', 'SMITH, JOHN A', 'RANK', 'SGT'];
  const back = ['DoD ID Number 1087987498'];

  test('requires the front before reading a DoD ID', () {
    final session = CacOcrSession();
    expect(session.process(back), isNull);
    expect(session.process(back), isNull);
    expect(session.side, CacScanSide.front);
    expect(session.guidance, contains('FRONT'));
  });

  test('reads both sides in order and retains the front name', () {
    final session = CacOcrSession();
    expect(session.process(front), isNull);
    expect(session.side, CacScanSide.front);
    expect(session.process(front), isNull);
    expect(session.side, CacScanSide.back);
    expect(session.guidance, contains('SMITH, JOHN A'));
    expect(session.guidance, contains('Flip to the BACK'));
    expect(session.process(back), isNull);
    final capture = session.process(back)!;
    expect(capture.barcode, '1087987498');
    expect(capture.name, (firstName: 'JOHN A', lastName: 'SMITH'));
    expect(capture.rejection, isNull);
  });

  test('a missing or different name interrupts consecutive agreement', () {
    final session = CacOcrSession();
    session.process(front);
    session.process([]);
    session.process(front);
    expect(session.side, CacScanSide.front);
    session.process(['NAME JONES, MARY']);
    session.process(front);
    expect(session.side, CacScanSide.front);
    session.process(front);
    expect(session.side, CacScanSide.back);
  });

  test('the front cannot supply a number before the card is flipped', () {
    final session = CacOcrSession();
    final frontWithNumber = [...front, ...back];
    session.process(frontWithNumber);
    session.process(frontWithNumber);
    expect(session.process(frontWithNumber), isNull);
    expect(session.process(frontWithNumber), isNull);
    expect(session.guidance, contains('Flip to the BACK'));
    expect(session.process(back), isNull);
    expect(session.process(back)!.barcode, '1087987498');
  });

  test('missing, invalid and different numbers interrupt back agreement', () {
    final session = CacOcrSession();
    session.process(front);
    session.process(front);
    for (final interruption in [
      <String>[],
      ['DoD ID Number 0000000001'],
      ['DoD Benefits Number 10879874981'],
      ['DoD ID Number 1098765432'],
    ]) {
      expect(session.process(back), isNull);
      expect(session.process(interruption), isNull);
    }
    expect(session.process(back), isNull);
    expect(session.process(back)!.name!.lastName, 'SMITH');
  });

  test('a timeout tells the operator which side could not be read', () {
    final session = CacOcrSession();
    expect(session.timeoutRejection, CacRejection.nameNotFound);
    session.process(front);
    session.process(front);
    expect(session.timeoutRejection, CacRejection.noCodeFound);
  });

  test('a new attempt cannot reuse a partial name from the previous scan', () {
    final abandoned = CacOcrSession();
    abandoned.process(front);
    abandoned.process(front);
    final retry = CacOcrSession();
    expect(retry.process(back), isNull);
    expect(retry.process(back), isNull);
    retry.process(['NAME JONES, MARY']);
    retry.process(['NAME JONES, MARY']);
    retry.process(back);
    expect(retry.process(back)!.name, (firstName: 'MARY', lastName: 'JONES'));
  });
}
