import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';

import '../../support/fakes.dart';

void main() {
  group('the operator copy', () {
    // The file's own stated policy, asserted rather than trusted: a Soldier in
    // gloves in the rain needs to know what to do next, and a message that
    // only diagnoses leaves them holding a walked PMCS and no next move. The
    // `expired` message was a bare 'That CAC is expired.' and is the reason
    // this group exists.
    for (final rejection in CacRejection.values) {
      test('${rejection.name} is a whole sentence, not a fragment', () {
        final message = rejection.message;

        expect(message, isNotEmpty);
        expect(message.trim(), message);
        expect(message, endsWith('.'));
      });
    }

    test('every rejection the operator can act on names an action', () {
      // `cancelled` is the one exception and stays one: the operator caused it
      // themselves and is already looking at SCAN AGAIN and SUBMIT UNVERIFIED,
      // so a sentence telling them to do what they can see would be noise.
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

    test('nothing tells the operator to scan "the front"', () {
      // At a gate a Soldier is trained to present the back, and every driving
      // licence in their wallet carries its PDF417 there too — so the bare
      // word reads as "the side I show the guard", which is the wrong face.
      // No exemptions any more: every message names landmarks instead.
      for (final rejection in CacRejection.values) {
        expect(rejection.message.toLowerCase(), isNot(contains('front')),
            reason: '${rejection.name} sends the operator to the wrong face');
      }
      expect(CacRejection.notACac.message,
          contains('your photo and the gold chip'));
    });

    test('the wrong-side message names landmarks and the gate strip', () {
      final message = CacRejection.wrongSideOfCard.message;

      expect(message, contains('gate guard'));
      expect(message, contains('gold chip'));
      expect(message, contains('bottom left'));
    });

    test('an expired card is told where to go, not just what it is', () {
      final message = CacRejection.expired.message;

      expect(message, contains('Draw a current card'));
      expect(message, contains('unverified'));
    });
  });

  group('isWorthRetrying', () {
    // Drives which control the refused card leads with, so a wrong answer here
    // either walks the operator round a loop that cannot end or hides the
    // retry from someone whose next photograph would have worked. Every enum
    // value is pinned, not a sample.
    const retryable = {
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
      // A value added to the enum and to neither set fails here rather than
      // quietly inheriting whichever answer happens to be first.
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

    test('a rejected scan carries no identity at all', () {
      const scan = CacScan.rejected(CacRejection.wrongSideOfCard);

      expect(scan.isVerified, isFalse);
      expect(scan.identity, isNull);
    });

    test('a capture is either text or a reason, never both', () {
      const read = CacCapture.read('1TPBOMMS10DINPAEDL');
      const failed = CacCapture.failed(CacRejection.cameraTimedOut);

      expect(read.rejection, isNull);
      expect(failed.barcode, isNull);
    });
  });
}
