import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/parse_cac_barcode.dart';

import 'package:cac_ocr/testing.dart';

void main() {
  final scannedAt = DateTime.utc(2026, 3, 24, 9);
  final parse = ParseCacBarcode(() => scannedAt);

  group('a current CAC', () {
    test('reads the Soldier off the card', () {
      final scan = parse(cacBarcode());

      expect(scan.isVerified, isTrue);
      final identity = scan.identity!;
      expect(identity.firstName, 'JOHN');
      expect(identity.lastName, 'SMITH');
      expect(identity.middleInitial, 'A');
      expect(identity.rank, 'SGT');
      expect(identity.branchCode, 'A');
      expect(identity.branch, 'US Army');
      expect(identity.categoryCode, 'A');
      expect(identity.category, 'Active Duty');
      expect(identity.cardInstance, 'K');
    });

    test('decodes the DoD ID number out of its base-32 packing', () {
      final identity = parse(cacBarcode()).identity!;

      expect(identity.dodId, '1087987498');
    });

    test('matches a second DMDC published sample', () {
      final identity = parse(cacBarcode(dodId: '1L6MPQI')).identity!;

      expect(identity.dodId, '1785423698');
    });

    test('decodes the date of birth field on the published sample date', () {
      final identity = parse(cacBarcode(expires: 'ATJ1')).identity;

      expect(identity, isNull);
      expect(
          parse(cacBarcode(expires: 'ATJ1')).rejection, CacRejection.expired);
    });

    test('keeps a short DoD ID number ten characters wide', () {
      final identity = parse(cacBarcode(dodId: '0TPLIG0')).identity!;

      expect(identity.dodId, '1000000000');
      expect(identity.dodId.length, 10);
    });

    test('decodes the card expiry off the 1 January 1000 day count', () {
      final identity = parse(cacBarcode()).identity!;

      expect(identity.cardExpiresOn, DateTime.utc(2028, 6, 30));
    });

    test('stamps the scan with the clock, not the card', () {
      final identity = parse(cacBarcode()).identity!;

      expect(identity.verifiedAt, DateTime.utc(2026, 3, 24, 9));
    });

    test('trims the space padding off the text fields', () {
      final identity = parse(cacBarcode(lastName: 'OYELARAN')).identity!;

      expect(identity.lastName, 'OYELARAN');
      expect(identity.rank, 'SGT');
    });

    test('reads a legacy version-1 card, which carries no middle initial', () {
      final scan = parse(cacBarcode(version: '1'));

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.lastName, 'SMITH');
      expect(scan.identity!.middleInitial, '');
    });

    test('ignores the start and stop sentinels some readers add', () {
      final scan = parse('*${cacBarcode()}*');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.dodId, '1087987498');
    });

    test('ignores surrounding whitespace', () {
      expect(parse('  ${cacBarcode()}\n').isVerified, isTrue);
    });

    test('reads a Soldier who has no middle name', () {
      final scan = parse(cacBarcode(middleInitial: ''));

      expect(scan.isVerified, isTrue,
          reason: 'a blank middle initial is a real card, not a bad scan');
      expect(scan.identity!.middleInitial, '');
      expect(scan.identity!.lastName, 'SMITH');
      expect(scan.identity!.displayName, 'SGT SMITH, JOHN');
    });

    test('reads a version-1 card whose card instance is blank', () {
      final scan = parse(cacBarcode(version: '1', cardInstance: ''));

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.cardInstance, '');
    });

    test('padding around a blank-initial record does not eat the field', () {
      final scan = parse('  \r\n${cacBarcode(middleInitial: '')}');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.middleInitial, '');
    });

    test('a reader that appends a newline does not lengthen the record', () {
      expect(parse('${cacBarcode(middleInitial: '')}\r\n').isVerified, isTrue);
      expect(parse('*${cacBarcode(middleInitial: '')}*\r\n').isVerified, isTrue,
          reason: 'sentinels and control characters both come off first');
    });
  });

  group('what is refused', () {
    test('a card issued before December 2012, because that field is an SSN',
        () {
      final scan = parse(cacBarcode(securityId: 'ABCDEF'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.legacySsnCard);
      expect(scan.identity, isNull);
    });

    test('the lowest post-2012 security id is still accepted', () {
      final scan = parse(cacBarcode(securityId: 'TP7RAO'));

      expect(scan.rejection, isNot(CacRejection.legacySsnCard));
    });

    test('an expired card, kept whole so the refusal can say whose it is', () {
      final scan = parse(cacBarcode(expires: 'BBQH'));

      expect(scan.isVerified, isFalse);
      expect(scan.identity, isNull);
      expect(scan.rejection, CacRejection.expired);
      expect(scan.expiredCard!.displayName, 'SGT SMITH, JOHN A');
      expect(scan.expiredCard!.cardExpiresOn, DateTime.utc(2020, 1, 15));
    });

    test('a card expiring today is still good, all day', () {
      for (final at in [
        DateTime.utc(2028, 6, 30),
        DateTime.utc(2028, 6, 30, 7),
        DateTime.utc(2028, 6, 30, 23, 59, 59),
      ]) {
        expect(ParseCacBarcode(() => at)(cacBarcode()).isVerified, isTrue,
            reason: 'a card printed 2028-06-30 is good at $at');
      }

      expect(
        ParseCacBarcode(() => DateTime.utc(2028, 7, 1))(cacBarcode()).rejection,
        CacRejection.expired,
        reason: 'and refused once the expiry day is behind them',
      );
    });

    test('the Code 39 strip off the back of the card, named as such', () {
      final scan = parse('1TPBOMMS10DINPAEDL');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.dodId, '1087987498');
      expect(scan.identity!.lastName, isEmpty);
      expect(scan.identity!.displayName, 'DoD ID 1087987498');
    });

    test('the same strip with the sentinels a reader tacks on', () {
      final scan = parse('*1TPBOMMS10DINPAEDL*');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.dodId, '1087987498');
    });

    group('an 18-character barcode that is not a CAC Code 39', () {
      void refusedAsNotACac(String description, String barcode) {
        test(description, () {
          expect(barcode.length, 18,
              reason: 'the fixture must be 18 wide or '
                  'it is testing the length gate instead');
          expect(parse(barcode).rejection, CacRejection.notACac);
          expect(parse(barcode).identity, isNull);
        });
      }

      refusedAsNotACac(
          'a run of digits off a part label', '123456789012345678');
      refusedAsNotACac('a run of letters', 'ABCDEFGHIJKLMNOPQR');
      refusedAsNotACac(
          'a URL that happens to be 18 wide', 'https://example.co');
      refusedAsNotACac(
          'a DoD ID number below the range DEERS issues', '1TPBOMMS0000001EDL');
      refusedAsNotACac('a digit where the branch code must be a letter',
          '1TPBOMMS10DINPAE1L');
      refusedAsNotACac('a character outside the base-32 alphabet in the EDIPI',
          '1TPBOMMS10DINPZEDL');
      refusedAsNotACac(
          'a version character that is not 1', '2TPBOMMS10DINPAEDL');
    });

    test('a Code 39 strip one character short is not coerced into one', () {
      expect(parse('1TPBOMMS10DINPAED').rejection, CacRejection.notACac);
      expect(parse('1TPBOMMS10DINPAEDLX').rejection, CacRejection.notACac);
    });

    test('a record of the right length but the wrong version code', () {
      final scan = parse(cacBarcode(version: 'X'));

      expect(scan.rejection, CacRejection.notACac);
    });

    test('a version-N record one character short', () {
      expect(
          parse(cacBarcode().substring(0, 88)).rejection, CacRejection.notACac);
    });

    test('an empty string', () {
      expect(parse('').rejection, CacRejection.notACac);
    });

    test('something else entirely', () {
      expect(parse('https://example.com/whatever').rejection,
          CacRejection.notACac);
    });

    test('a base-32 field carrying a character outside the alphabet', () {
      final scan = parse(cacBarcode(dodId: '10DINPZ'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.notACac);
    });

    test('a DoD ID number below the range DEERS issues', () {
      final scan = parse(cacBarcode(dodId: '0000001'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.notACac);
    });
  });

  group('what is deliberately not kept', () {
    test('the date of birth never reaches the identity', () {
      final identity = parse(cacBarcode()).identity!;

      expect(identity.toMap().keys, isNot(contains('dateOfBirth')));
      expect(identity.toMap().values, isNot(contains('1980-02-18')));
    });

    test('the card security identifier never reaches the identity', () {
      final identity = parse(cacBarcode()).identity!;
      final serialised = identity.toMap().toString();

      expect(serialised, isNot(contains('999551212')));
      expect(identity.toMap().keys, isNot(contains('securityId')));
    });
  });

  group('telling the barcodes apart for a live scan', () {
    test('the front record is recognised by its shape alone', () {
      expect(ParseCacBarcode.isFrontRecord(cacBarcode()), isTrue);
      expect(ParseCacBarcode.isFrontRecord('*${cacBarcode()}*\n'), isTrue);
      expect(ParseCacBarcode.isFrontRecord(cacBarcode(version: '1')), isTrue);
      expect(ParseCacBarcode.isFrontRecord('1TPBOMMS10DINPAEDL'), isFalse);
      expect(ParseCacBarcode.isFrontRecord('ANSI 636000080002DL'), isFalse);
    });

    test('the back strip gives its DoD ID, and nothing else does', () {
      expect(
          ParseCacBarcode.dodIdFromCode39('1TPBOMMS10DINPAEDL'), '1087987498');
      expect(ParseCacBarcode.dodIdFromCode39('*1TPBOMMS10DINPAEDL*'),
          '1087987498');
      expect(ParseCacBarcode.dodIdFromCode39('1TPBOMMS10DINPAED'), isNull);
      expect(ParseCacBarcode.dodIdFromCode39(cacBarcode()), isNull);
    });
  });
}
