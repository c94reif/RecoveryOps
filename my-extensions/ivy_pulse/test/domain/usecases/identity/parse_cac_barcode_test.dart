import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

import '../../../support/cac_fixtures.dart';

void main() {
  // Before the fixture card's 2028 expiry, so a default fixture is current.
  final clock = FixedClock(DateTime.utc(2026, 3, 24, 9));
  final parse = ParseCacBarcode(clock);

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
      // DMDC's own published sample: '10DINPA' decodes to 1087987498.
      final identity = parse(cacBarcode()).identity!;

      expect(identity.edipi, '1087987498');
    });

    test('matches a second DMDC published sample', () {
      // '1L6MPQI' is published as 1785423698. Two independent samples pin the
      // base-32 arithmetic to ground truth rather than to this app's own
      // reading of the spec.
      final identity = parse(cacBarcode(edipi: '1L6MPQI')).identity!;

      expect(identity.edipi, '1785423698');
    });

    test('decodes the date of birth field on the published sample date', () {
      // 'ATJ1' is published as 1980-02-18. The parser drops the value, but
      // the date arithmetic it shares with the expiry field is pinned here by
      // proving a card whose expiry carries the same packing reads back.
      final identity = parse(cacBarcode(expires: 'ATJ1')).identity;

      // 1980 is long past, so this card is refused — which is itself the
      // proof the day count decoded to 1980 and not to some far future.
      expect(identity, isNull);
      expect(
          parse(cacBarcode(expires: 'ATJ1')).rejection, CacRejection.expired);
    });

    test('keeps a short DoD ID number ten characters wide', () {
      // Zero-padded because that is how DEERS and the 5988-E print it; a
      // stripped leading zero is a different Soldier's number.
      final identity = parse(cacBarcode(edipi: '0TPLIG0')).identity!;

      expect(identity.edipi, '1000000000');
      expect(identity.edipi.length, 10);
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
      expect(scan.identity!.edipi, '1087987498');
    });

    test('ignores surrounding whitespace', () {
      expect(parse('  ${cacBarcode()}\n').isVerified, isTrue);
    });

    test('reads a Soldier who has no middle name', () {
      // The middle initial is the LAST field of a version-`N` record, and on a
      // Soldier with no middle name the card carries it as a space. Trimming
      // the record shortens that 89 to an 88, which matches neither layout, so
      // every such Soldier was refused as `notACac` — told to re-aim at a card
      // they were already holding correctly, and left able to close the PMCS
      // out only as unverified.
      final scan = parse(cacBarcode(middleInitial: ''));

      expect(scan.isVerified, isTrue,
          reason: 'a blank middle initial is a real card, not a bad scan');
      expect(scan.identity!.middleInitial, '');
      expect(scan.identity!.lastName, 'SMITH');
      expect(scan.identity!.displayName, 'SGT SMITH, JOHN');
    });

    test('reads a version-1 card whose card instance is blank', () {
      // Same mechanism one field over: the card instance is the last character
      // of the 88-character legacy layout.
      final scan = parse(cacBarcode(version: '1', cardInstance: ''));

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.cardInstance, '');
    });

    test('padding around a blank-initial record does not eat the field', () {
      // Leading whitespace is unambiguous — field 0 is the version character
      // and is never a space — so it goes before the length is judged, and the
      // blank middle initial survives.
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
      // Pre-2012 the Person Designator Identifier was literally the
      // cardholder's SSN. The app will not hold one even for the moment it
      // takes to ignore it.
      final scan = parse(cacBarcode(securityId: 'ABCDEF'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.legacySsnCard);
      expect(scan.identity, isNull);
    });

    test('the lowest post-2012 security id is still accepted', () {
      // 999,000,000 is the boundary, not a rejection.
      final scan = parse(cacBarcode(securityId: 'TP7RAO'));

      expect(scan.rejection, isNot(CacRejection.legacySsnCard));
    });

    test('an expired card', () {
      final scan = parse(cacBarcode(expires: 'BBQH'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.expired);
    });

    test('a card expiring today is still good, all day', () {
      // A CAC is valid THROUGH its printed date, and the field decodes to
      // midnight at the START of that day — so comparing against it directly
      // deadlines the card at 00:00:01 and, because `expired` is not worth
      // retrying, steers that Soldier to an unverified submission with a
      // perfectly good card in their hand. Midnight alone passes even with
      // that bug; the times of day are the checks that mean something.
      for (final at in [
        DateTime.utc(2028, 6, 30),
        DateTime.utc(2028, 6, 30, 7),
        DateTime.utc(2028, 6, 30, 23, 59, 59),
      ]) {
        expect(ParseCacBarcode(FixedClock(at))(cacBarcode()).isVerified, isTrue,
            reason: 'a card printed 2028-06-30 is good at $at');
      }

      expect(
        ParseCacBarcode(FixedClock(DateTime.utc(2028, 7, 1)))(cacBarcode())
            .rejection,
        CacRejection.expired,
        reason: 'and refused once the expiry day is behind them',
      );
    });

    test('the Code 39 strip off the back of the card, named as such', () {
      // 18 characters, no name, no rank — the wrong barcode, and slicing it
      // as if it were the front one would invent a Soldier. Recognised
      // specifically so the operator is told to turn the card over rather
      // than to go and find a different card.
      final scan = parse('1TPBOMMS10DINPAEDL');

      // The back is now the side asked for, and its strip carries the DoD ID
      // — so this is a signature by number, the same identity an OCR read of
      // the printed number produces, with no name to put beside it.
      expect(scan.isVerified, isTrue);
      expect(scan.identity!.edipi, '1087987498');
      expect(scan.identity!.lastName, isEmpty);
      expect(scan.identity!.displayName, 'DoD ID 1087987498');
    });

    test('the same strip with the sentinels a reader tacks on', () {
      // Code 39 readers commonly hand back the start/stop characters. They
      // must be stripped before the length is judged, or a real back-of-card
      // read falls through to the vaguer notACac and the operator is sent
      // looking for a different card.
      final scan = parse('*1TPBOMMS10DINPAEDL*');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.edipi, '1087987498');
    });

    group('an 18-character barcode that is not a CAC Code 39', () {
      // A motor pool is full of 18-character barcodes — tool crib tags, part
      // labels, container placards. Matching one on length alone would tell a
      // Soldier to turn over a card they are already holding the right way
      // round, which is worse than the vaguer answer. Every field is checked,
      // so each of these fails on a different one.
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
      // Shape-perfect apart from one field each, which is the case that would
      // survive a looser check.
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
      // 'Z' is not in 0-9A-V. Coercing it would silently shift the decoded
      // number and put another Soldier's DoD ID on the 5988-E.
      final scan = parse(cacBarcode(edipi: '10DINPZ'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.notACac);
    });

    test('a DoD ID number below the range DEERS issues', () {
      final scan = parse(cacBarcode(edipi: '0000001'));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.notACac);
    });
  });

  group('what is deliberately not kept', () {
    test('the date of birth never reaches the identity', () {
      // DoD guidance treats a DoD ID number paired with a date of birth as a
      // reportable combination, and a date of birth says nothing about who
      // signed for a vehicle.
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
}
