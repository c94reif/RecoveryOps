import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_identity.dart';

import '../../support/fakes.dart';

void main() {
  /// A card that runs out [days] after it was scanned.
  ///
  /// Both ends come off the same instant on purpose: `verifiedAt` is already
  /// the scan moment off the injected clock, so the arithmetic under test
  /// takes no clock of its own and stays deterministic.
  CacIdentity cardExpiringIn(int days, {int scannedAtHour = 7}) {
    final scannedAt = DateTime.utc(2026, 3, 24, scannedAtHour);
    return buildIdentity(
      verifiedAt: scannedAt,
      cardExpiresOn: DateTime.utc(2026, 3, 24).add(Duration(days: days)),
    );
  }

  /// A card whose barcode carried no expiry field at all. Reachable from
  /// `CacIdentity.fromMap` on a report written by an older build.
  final noExpiry = CacIdentity(
    edipi: '1087987498',
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
      // Both ends are cut back to UTC calendar days because a card expires on
      // a day, not at an instant. Without that, a card scanned at 23:00 the
      // day before its expiry counts 0 days instead of 1 and the copy says
      // "expires today" to a Soldier whose card is good tomorrow.
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
      // Thirty days is the window a Soldier can act inside — an ID card
      // appointment is rarely same-week. A card exactly on the boundary is
      // inside it, not one day too late.
      expect(CacIdentity.expiryWarningDays, 30);
      expect(cardExpiringIn(30).isCardExpiringSoon, isTrue);
    });

    test('a card down to its last days warns', () {
      expect(cardExpiringIn(12).isCardExpiringSoon, isTrue);
      expect(cardExpiringIn(1).isCardExpiringSoon, isTrue);
      expect(cardExpiringIn(0).isCardExpiringSoon, isTrue);
    });

    test('a card already dead still warns', () {
      // The scan gate refuses an expired card outright, so this only reaches
      // here through an identity restored from an older report — and the
      // maintainer reading that signature block still wants to be told.
      expect(cardExpiringIn(-3).isCardExpiringSoon, isTrue);
    });

    test('a card with no expiry field warns about nothing', () {
      expect(noExpiry.isCardExpiringSoon, isFalse);
    });
  });

  group('cardExpiryCountdown', () {
    test('reads as the tail of "expires ___"', () {
      expect(cardExpiringIn(0).cardExpiryCountdown, 'today');
      expect(cardExpiringIn(1).cardExpiryCountdown, 'tomorrow');
      expect(cardExpiringIn(12).cardExpiryCountdown, 'in 12 days');
      expect(cardExpiringIn(2).cardExpiryCountdown, 'in 2 days');
    });

    test('an empty string when the card carried no expiry', () {
      expect(noExpiry.cardExpiryCountdown, '');
    });

    test('a past date says so rather than counting backwards', () {
      // 'in -3 days' is the off-by-one lie this case exists to refuse.
      expect(cardExpiringIn(-3).cardExpiryCountdown, 'expired');
    });
  });
}
