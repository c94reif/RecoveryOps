import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:circle_x/presentation/inspection/pmcs_sign_off_text.dart';

void main() {
  group('the PMCS refusal copy', () {
    // The card's own copy cannot know a PMCS has an unverified way out; this
    // one has to say so wherever another scan will not get the operator there.
    test('points every dead end at the unverified submission', () {
      for (final rejection in [
        CacRejection.expired,
        CacRejection.cameraTimedOut,
        CacRejection.noCamera,
      ]) {
        final message = pmcsRejectionMessage(rejection);

        expect(message.toLowerCase(), contains('submit unverified'),
            reason: '${rejection.name}: "$message"');
        expect(message, endsWith('.'));
      }
    });

    test('an expired card is told where to go, not just what it is', () {
      final message = pmcsRejectionMessage(CacRejection.expired);

      expect(message, contains('Draw a current card'));
      expect(message, contains('unverified'));
    });

    test('anything a rescan can fix keeps the card copy', () {
      for (final rejection in [
        CacRejection.nameNotFound,
        CacRejection.noCodeFound,
        CacRejection.wrongSideOfCard,
        CacRejection.cancelled,
      ]) {
        expect(pmcsRejectionMessage(rejection), rejection.message);
      }
    });
  });

  test('the sign-off speaks of the PMCS it signs', () {
    expect(pmcsSignOffText.submitButton, 'SUBMIT PMCS');
    expect(pmcsSignOffText.promptBothSides, startsWith('A PMCS is signed'));
    expect(pmcsSignOffText.promptBackOnly, startsWith('A PMCS is signed'));
    expect(pmcsSignOffText.galleryAdvisory, startsWith('circle-x'));
    expect(pmcsSignOffText.rejectionMessage(CacRejection.noCamera),
        pmcsRejectionMessage(CacRejection.noCamera));
  });
}
