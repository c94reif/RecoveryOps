import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

import '../support/identities.dart';

void main() {
  String? retryHint(int attempts, {bool bothSides = false}) =>
      const CacOcrText().retryHint!(attempts, bothSides);

  group('the default retry hint: what the operator is told, and when', () {
    test('nothing before a scan has been tried', () {
      expect(retryHint(0), isNull);
    });

    test('nothing on the first miss', () {
      expect(retryHint(1), isNull);
    });

    test('the second miss offers the rotation, which is the non-obvious one',
        () {
      final hint = retryHint(2);

      expect(hint, isNotNull);
      expect(hint, contains('fill the box'));
      expect(hint, contains('across the frame'));
    });

    test('the third miss moves on to glare, which framing cannot fix', () {
      final hint = retryHint(3);

      expect(hint, isNotNull);
      expect(hint, contains('shadow'));
      expect(hint, isNot(contains('fill the box')),
          reason: 'repeating advice that has already failed twice reads as '
              'the app not listening');
    });

    test('the advice stops escalating rather than running out', () {
      expect(retryHint(4), retryHint(3));
      expect(retryHint(9), retryHint(3));
      expect(retryHint(99), retryHint(3));
    });

    test('a negative count cannot crash the refused card', () {
      expect(retryHint(-1), isNull);
    });

    test(
        'both hints are instructions the Soldier can carry out standing '
        'there', () {
      for (final hint in [retryHint(2)!, retryHint(3)!]) {
        expect(hint, endsWith('.'));
        expect(hint.toLowerCase(), isNot(contains('lighting')));
        expect(hint.toLowerCase(), isNot(contains('scanner')));
      }
    });
  });

  group('the default expiry warning', () {
    String warningFor(int days) {
      final scannedAt = DateTime.utc(2026, 3, 24, 7);
      final CacIdentity card = buildIdentity(
        verifiedAt: scannedAt,
        cardExpiresOn: DateTime.utc(2026, 3, 24).add(Duration(days: days)),
      );
      return const CacOcrText().expiringSoon!(card);
    }

    test('reads the days left as the tail of "expires ___"', () {
      expect(warningFor(0), startsWith('This CAC expires today.'));
      expect(warningFor(1), startsWith('This CAC expires tomorrow.'));
      expect(warningFor(2), startsWith('This CAC expires in 2 days.'));
      expect(warningFor(12), startsWith('This CAC expires in 12 days.'));
    });

    test('a past date says so rather than counting backwards', () {
      expect(
          warningFor(-3), 'This CAC expired 21 MAR 2026. Draw a current card.');
    });
  });
}
