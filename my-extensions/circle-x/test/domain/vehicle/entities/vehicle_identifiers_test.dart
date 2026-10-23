import 'package:circle_x/domain/vehicle/entities/bumper_number.dart';
import 'package:circle_x/domain/profile/entities/uic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bumper matching tolerates case, spaces and optional hyphens', () {
    for (final value in [
      'HHC112',
      ' hhc 112 ',
      'HHC-112',
      'HHC \t 112\n',
      'HHC\u00a0112',
      'HHC\u202f112',
      'HHC\u2011112',
      'HHC\u2013112',
      'HHC\uff0d112',
    ]) {
      expect(BumperNumber.matchingKey(value), 'HHC112', reason: value);
    }
    expect(BumperNumber.normalize(' hhc 112 '), 'HHC112');
    expect(BumperNumber.normalize(' hhc - 112 '), 'HHC-112');
  });

  test('bumper matching preserves distinct numbers and lookalike characters',
      () {
    for (final pair in [
      ('HHC112', 'HHC113'),
      ('HHC0112', 'HHC112'),
      ('HHC1O2', 'HHC102'),
      ('HHCI12', 'HHC112'),
      ('HHC/112', 'HHC112'),
      ('HHC.112', 'HHC112'),
    ]) {
      expect(BumperNumber.matchingKey(pair.$1),
          isNot(BumperNumber.matchingKey(pair.$2)));
    }
  });

  test('UIC validation ignores whitespace without truncating or guessing', () {
    for (final value in [
      'WJ8TAA',
      ' wj8 taa ',
      '\twj8\n taa\r',
      'WJ8\u00a0TAA',
      'WJ8\u202fTAA',
    ]) {
      expect(Uic.normalize(value), 'WJ8TAA');
      expect(Uic.validate(value), isNull);
    }
    expect(Uic.normalize('w0 i 01a'), 'W0I01A');
    expect(Uic.validate(' \t\n '), 'UIC is required');
    expect(Uic.validate('wj8 ta'), 'UIC must be exactly 6 characters');
    expect(Uic.validate('wj8 taaa'), 'UIC must be exactly 6 characters');
    expect(Uic.isValid('WJ8-TAA'), isFalse);
    expect(Uic.isValid('WJ8!AA'), isFalse);
  });
}
