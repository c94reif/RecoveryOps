import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';

import '../support/identities.dart';

void main() {
  CacIdentity cardExpiringIn(int days, {int scannedAtHour = 7}) {
    final scannedAt = DateTime.utc(2026, 3, 24, scannedAtHour);
    return buildIdentity(
      verifiedAt: scannedAt,
      cardExpiresOn: DateTime.utc(2026, 3, 24).add(Duration(days: days)),
    );
  }

  final noExpiry = CacIdentity(
    dodId: '1087987498',
    firstName: 'JOHN',
    lastName: 'SMITH',
    verifiedAt: DateTime.utc(2026, 3, 24, 7),
  );

  group('daysUntilCardExpiry', () {
    test('counts whole days from the scan to the expiry', () {
      expect(cardExpiringIn(12).daysUntilCardExpiry, 12);
      expect(cardExpiringIn(90).daysUntilCardExpiry, 90);
    });

    test('a card expiring today counts zero', () {
      expect(cardExpiringIn(0).daysUntilCardExpiry, 0);
    });

    test('a card already past its date counts negative', () {
      expect(cardExpiringIn(-3).daysUntilCardExpiry, -3);
    });

    test('a late-evening scan does not read a day short', () {
      expect(cardExpiringIn(1, scannedAtHour: 23).daysUntilCardExpiry, 1);
      expect(cardExpiringIn(30, scannedAtHour: 23).daysUntilCardExpiry, 30);
    });

    test('a card with no expiry field answers null rather than guessing', () {
      expect(noExpiry.daysUntilCardExpiry, isNull);
    });
  });

  group('isCardExpiringSoon', () {
    test('a card well inside its life raises nothing', () {
      expect(cardExpiringIn(90).isCardExpiringSoon, isFalse);
      expect(
          cardExpiringIn(CacIdentity.expiryWarningDays + 1).isCardExpiringSoon,
          isFalse);
    });

    test('the warning window is inclusive at its edge', () {
      expect(CacIdentity.expiryWarningDays, 30);
      expect(cardExpiringIn(30).isCardExpiringSoon, isTrue);
    });

    test('a card down to its last days warns', () {
      expect(cardExpiringIn(12).isCardExpiringSoon, isTrue);
      expect(cardExpiringIn(1).isCardExpiringSoon, isTrue);
      expect(cardExpiringIn(0).isCardExpiringSoon, isTrue);
    });

    test('a card already dead still warns', () {
      expect(cardExpiringIn(-3).isCardExpiringSoon, isTrue);
    });

    test('a card with no expiry field warns about nothing', () {
      expect(noExpiry.isCardExpiringSoon, isFalse);
    });
  });

  group('isCardExpired', () {
    test('a card is good through its printed day', () {
      expect(cardExpiringIn(0).isCardExpired, isFalse);
      expect(cardExpiringIn(0, scannedAtHour: 23).isCardExpired, isFalse);
      expect(cardExpiringIn(-1).isCardExpired, isTrue);
    });

    test('a card with no expiry field is never called expired', () {
      expect(noExpiry.isCardExpired, isFalse);
    });
  });

  group('displayName', () {
    test('reads rank, surname, given name and initial', () {
      expect(buildIdentity().displayName, 'SGT SMITH, JOHN A');
      expect(buildIdentity(rank: '', middleInitial: '').displayName,
          'SMITH, JOHN');
    });

    test('keeps whichever half of the name the card gave', () {
      expect(buildIdentity(firstName: '', middleInitial: '').displayName,
          'SGT SMITH');
      expect(buildIdentity(lastName: '', rank: '').displayName, 'JOHN A');
    });

    test('falls back to the DoD ID when no name was read', () {
      expect(
          buildIdentity(
                  firstName: '', lastName: '', middleInitial: '', rank: '')
              .displayName,
          'DoD ID 1087987498');
    });
  });

  group('service and category labels', () {
    test('name the service a maintainer would recognise', () {
      expect(buildIdentity(branchCode: 'M').branch, 'US Marine Corps');
      expect(buildIdentity(branchCode: 'N').branch, 'US Navy');
    });

    test('a contractor reads differently from a Soldier', () {
      expect(buildIdentity(categoryCode: 'E').category, 'DoD Contractor');
      expect(buildIdentity(categoryCode: 'N').category, 'National Guard');
    });

    test('every code the card spec defines has a name', () {
      for (final code in 'ACDFHMNO'.split('')) {
        expect(buildIdentity(branchCode: code).branch, isNot(code));
      }
      for (final code in 'ACEINORVW'.split('')) {
        expect(buildIdentity(categoryCode: code).category, isNot(code));
      }
      expect(buildIdentity(branchCode: '', categoryCode: '').branch, '');
      expect(buildIdentity(branchCode: '', categoryCode: '').category, '');
      expect(buildIdentity(categoryCode: 'Z').category, 'Z');
    });

    test('a code this build does not know shows the code, not a guess', () {
      expect(buildIdentity(branchCode: 'S').branch, 'S');
    });
  });

  group('storage', () {
    test('round-trips every field it carries', () {
      final identity = buildIdentity();
      final restored = CacIdentity.fromMap(identity.toMap())!;

      expect(restored.displayName, identity.displayName);
      expect(restored.branchCode, 'A');
      expect(restored.categoryCode, 'A');
      expect(restored.cardInstance, 'K');
      expect(restored.cardExpiresOn, identity.cardExpiresOn);
      expect(restored.verifiedAt, identity.verifiedAt);
    });

    test('leaves out the optional fields a card did not carry', () {
      final map = noExpiry.toMap();

      expect(map.keys, ['edipi', 'firstName', 'lastName', 'verifiedAt']);
      expect(CacIdentity.fromMap(map)!.cardExpiresOn, isNull);
    });

    test('tolerates fields a newer build added', () {
      final restored = CacIdentity.fromMap({
        ...buildIdentity().toMap(),
        'somethingNew': 'ignored',
      });

      expect(restored, isNotNull);
      expect(restored!.dodId, '1087987498');
    });

    test('refuses a record that cannot be a person', () {
      final good = buildIdentity().toMap();
      for (final broken in <Map<String, Object?>>[
        {...good, 'edipi': '0000000001'},
        {...good, 'edipi': 1087987498},
        {...good}..remove('firstName'),
        {...good, 'lastName': 7},
        {...good, 'verifiedAt': 'yesterday'},
        {...good}..remove('verifiedAt'),
        {...good, 'cardExpiresOn': 20280630},
        {...good, 'cardExpiresOn': 'soon'},
        {...good, 'rank': 5},
      ]) {
        expect(CacIdentity.fromMap(broken), isNull, reason: '$broken');
      }
    });
  });
}
