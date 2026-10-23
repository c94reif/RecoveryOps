import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/parse_dod_id.dart';

void main() {
  final scannedAt = DateTime.utc(2026, 3, 24, 9);
  final parse = ParseDodId(() => scannedAt);

  group('a DoD ID number read off the back of the card', () {
    test('signs the PMCS by number, with no name to put beside it', () {
      final scan = parse('1087987498');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.dodId, '1087987498');
      expect(scan.identity!.firstName, isEmpty);
      expect(scan.identity!.lastName, isEmpty);
      expect(scan.identity!.rank, isEmpty);
      expect(scan.identity!.displayName, 'DoD ID 1087987498');
    });

    test('is stamped with the scan instant off the injected clock', () {
      expect(parse('1087987498').identity!.verifiedAt, scannedAt);
    });

    test('tolerates the spaces and dashes OCR leaves in', () {
      expect(parse('1087 987 498').identity?.dodId, '1087987498');
      expect(parse('1087-987-498').identity?.dodId, '1087987498');
    });

    test('refuses anything that is not ten digits', () {
      expect(parse('108798749').rejection, CacRejection.notACac);
      expect(parse('10879874981').rejection, CacRejection.notACac);
      expect(parse('').rejection, CacRejection.notACac);
      expect(parse('SGT SMITH').rejection, CacRejection.notACac);
    });

    test('refuses ten digits DEERS has never issued', () {
      expect(parse('0000000001').rejection, CacRejection.notACac);
      expect(parse('0999999999').rejection, CacRejection.notACac);
    });

    test('does not discard an unreadable digit to manufacture ten digits', () {
      for (final raw in ['10879O87498', '1087987498?', '1087987498-1']) {
        expect(parse(raw).isVerified, isFalse);
        expect(parse(raw).rejection, CacRejection.notACac);
      }
    });
  });

  group('the front read beside it', () {
    test('carries the rank and expiry into the identity', () {
      final identity = parse('1087987498',
              name: (firstName: 'JOHN A', lastName: 'SMITH'),
              rank: 'SGT',
              expiresOn: DateTime.utc(2028, 9, 30))
          .identity!;

      expect(identity.displayName, 'SGT SMITH, JOHN A');
      expect(identity.cardExpiresOn, DateTime.utc(2028, 9, 30));
    });

    test('refuses a card past its date and keeps it for the refusal', () {
      final scan = parse('1087987498',
          name: (firstName: 'JOHN A', lastName: 'SMITH'),
          rank: 'SGT',
          expiresOn: DateTime.utc(2026, 3, 23));

      expect(scan.isVerified, isFalse);
      expect(scan.rejection, CacRejection.expired);
      expect(scan.expiredCard!.displayName, 'SGT SMITH, JOHN A');
      expect(scan.expiredCard!.dodId, '1087987498');
    });

    test('a card expiring today is still good', () {
      expect(
          parse('1087987498', expiresOn: DateTime.utc(2026, 3, 24)).isVerified,
          isTrue);
    });
  });

  test('an expiry further out than any card is issued for is a misread', () {
    final identity =
        parse('1087987498', expiresOn: DateTime.utc(2079, 9, 30)).identity!;

    expect(identity.cardExpiresOn, isNull,
        reason: 'a CAC is issued for three years at most');
  });
}
