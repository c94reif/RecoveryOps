import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/testing.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_scan.dart';

import '../support/identities.dart';

void main() {
  group('the operator copy', () {
    for (final rejection in CacRejection.values) {
      test('${rejection.name} is a whole sentence, not a fragment', () {
        final message = rejection.message;

        expect(message, isNotEmpty);
        expect(message.trim(), message);
        expect(message, endsWith('.'));
      });
    }

    test('every rejection the operator can act on names an action', () {
      const verbs = [
        'fill',
        'wipe',
        'turn',
        'scan',
        'draw',
        'try again',
        'move closer',
        'submit unverified',
      ];
      for (final rejection in CacRejection.values) {
        if (rejection == CacRejection.cancelled) continue;
        final message = rejection.message.toLowerCase();
        expect(verbs.any(message.contains), isTrue,
            reason: '${rejection.name} diagnoses without instructing: '
                '"${rejection.message}"');
      }
    });

    test('name and number failures identify the correct card landmarks', () {
      expect(CacRejection.nameNotFound.message, contains('front'));
      expect(CacRejection.nameNotFound.message, contains('your photo'));
      expect(CacRejection.noCodeFound.message, contains('back'));
      expect(CacRejection.notACac.message, contains('wide barcode strip'));
    });

    test('the wrong-side message names landmarks and the gate strip', () {
      final message = CacRejection.wrongSideOfCard.message;

      expect(message, contains('your photo'));
      expect(message, contains('DoD ID number'));
      expect(message, contains('wide barcode strip'));
    });

    test('an expired card is told where to go, not just what it is', () {
      final message = CacRejection.expired.message;

      expect(message, contains('Draw a current card'));
    });

    test('says nothing about a submission flow the app may not have', () {
      for (final rejection in CacRejection.values) {
        expect(rejection.message.toLowerCase(), isNot(contains('unverified')));
        expect(rejection.message, isNot(contains('PMCS')));
      }
    });
  });

  group('isWorthRetrying', () {
    const retryable = {
      CacRejection.nameNotFound,
      CacRejection.noCodeFound,
      CacRejection.codeUnreadable,
      CacRejection.cardTooSmall,
      CacRejection.notACac,
      CacRejection.wrongSideOfCard,
      CacRejection.cancelled,
      CacRejection.cameraTimedOut,
    };
    const settled = {
      CacRejection.legacySsnCard,
      CacRejection.expired,
      CacRejection.noCamera,
    };

    test('the two sets between them cover every rejection', () {
      expect({...retryable, ...settled}, CacRejection.values.toSet());
      expect(retryable.intersection(settled), isEmpty);
    });

    for (final rejection in retryable) {
      test('${rejection.name} is worth another photograph', () {
        expect(rejection.isWorthRetrying, isTrue);
      });
    }

    for (final rejection in settled) {
      test('${rejection.name} returns the same answer however it is shot', () {
        expect(rejection.isWorthRetrying, isFalse);
      });
    }
  });

  group('CacScan', () {
    test('a verified scan carries an identity and no rejection', () {
      final scan = CacScan.verified(buildIdentity());

      expect(scan.isVerified, isTrue);
      expect(scan.rejection, isNull);
    });

    test('an expired scan is refused but keeps the card for the refusal', () {
      final card = buildIdentity(cardExpiresOn: DateTime.utc(2025, 1, 1));
      final scan = CacScan.expired(card);

      expect(scan.isVerified, isFalse);
      expect(scan.identity, isNull);
      expect(scan.rejection, CacRejection.expired);
      expect(scan.expiredCard, same(card));
      expect(const CacScan.rejected(CacRejection.expired).expiredCard, isNull);
    });

    test('a rejected scan carries no identity at all', () {
      const scan = CacScan.rejected(CacRejection.wrongSideOfCard);

      expect(scan.isVerified, isFalse);
      expect(scan.identity, isNull);
    });

    test('a capture is one kind: a barcode, read fields, or a reason', () {
      const barcode = CacCapture.barcode('1TPBOMMS10DINPAEDL');
      const fields = CacCapture.fields('1087987498');
      const failed = CacCapture.failed(CacRejection.cameraTimedOut);

      expect(barcode.asBarcode.raw, '1TPBOMMS10DINPAEDL');
      expect(fields.asFields.dodId, '1087987498');
      expect(fields.asFields.rank, isEmpty);
      expect([barcode.rejection, fields.rejection], [null, null]);
      expect(failed.rejection, CacRejection.cameraTimedOut);
    });
  });
}
