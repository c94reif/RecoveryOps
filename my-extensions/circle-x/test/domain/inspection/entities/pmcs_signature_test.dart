import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:circle_x/domain/inspection/entities/pmcs_signature.dart';

import '../../../support/fakes.dart';

void main() {
  group('the name on the 5988-E', () {
    test('reads rank, surname, given name and initial', () {
      expect(buildIdentity().displayName, 'SGT SMITH, JOHN A');
    });

    test('drops the initial a legacy card does not carry', () {
      expect(
        buildIdentity(middleInitial: '').displayName,
        'SGT SMITH, JOHN',
      );
    });

    test('survives a card with no rank printed', () {
      expect(buildIdentity(rank: '').displayName, 'SMITH, JOHN A');
    });

    test('falls back to the DoD ID when the card carried no name at all', () {
      // Better an unambiguous number than a blank signature block.
      expect(
        buildIdentity(firstName: '', lastName: '', middleInitial: '', rank: '')
            .displayName,
        'DoD ID 1087987498',
      );
    });

    test('an unverified signature says so in the operator column', () {
      expect(buildUnverifiedSignature().displayName, 'UNVERIFIED');
    });
  });

  group('the typed fallback', () {
    const typed = AttestedIdentity(
      dodId: '1087987498',
      firstName: 'JOHN',
      lastName: 'SMITH',
    );
    final signature = PmcsSignature.unverified(
      blockedBy: CacRejection.codeUnreadable,
      signedAt: DateTime.utc(2026, 3, 24, 9),
      attestedBy: typed,
    );

    test('puts the typed name in the operator column', () {
      expect(signature.displayName, 'SMITH, JOHN');
    });

    test('is never verified, however complete the entry', () {
      expect(signature.isVerified, isFalse);
      expect(signature.identity, isNull);
      expect(signature.method, 'typed');
      expect(signature.blockedReason, isNotEmpty);
    });

    test('carries the DoD ID so the maintainer has a number to chase', () {
      expect(signature.dodId, '1087987498');
      expect(buildUnverifiedSignature().dodId, isNull);
      expect(buildSignature().dodId, '1087987498');
    });

    test('a scanned signature reports cac, an unsigned one none', () {
      expect(buildSignature().method, 'cac');
      expect(buildUnverifiedSignature().method, 'none');
    });

    test('round-trips through the wire without being promoted', () {
      final back = PmcsSignature.fromMap(signature.toMap());

      expect(back, isNotNull);
      expect(back!.isVerified, isFalse);
      expect(back.attestedBy?.displayName, 'SMITH, JOHN');
      expect(back.attestedBy?.dodId, '1087987498');
      expect(back.blockedBy, CacRejection.codeUnreadable);
    });

    test('a build that does not know the field reads it as plain unverified',
        () {
      final map = signature.toMap()..remove('attestedBy');
      final back = PmcsSignature.fromMap(map);

      expect(back!.isVerified, isFalse);
      expect(back.attestedBy, isNull);
      expect(back.displayName, 'UNVERIFIED');
    });
  });

  group('storage and the wire', () {
    test('a verified signature round-trips', () {
      final restored = PmcsSignature.fromMap(buildSignature().toMap())!;

      expect(restored.isVerified, isTrue);
      expect(restored.identity!.dodId, '1087987498');
      expect(restored.identity!.displayName, 'SGT SMITH, JOHN A');
      expect(restored.signedAt, DateTime.utc(2026, 3, 24, 9));
    });

    test('an unverified signature round-trips with its reason', () {
      final restored = PmcsSignature.fromMap(
        buildUnverifiedSignature(blockedBy: CacRejection.expired).toMap(),
      )!;

      expect(restored.isVerified, isFalse);
      expect(restored.blockedBy, CacRejection.expired);
      expect(restored.blockedReason, CacRejection.expired.message);
    });

    test('an empty blob is no signature at all, not a verified one', () {
      expect(PmcsSignature.fromMap(const {}), isNull);
    });

    test('a blob claiming verified with no identity stays unverified', () {
      // The one promotion that must never happen.
      final restored = PmcsSignature.fromMap(const {'verified': true})!;

      expect(restored.isVerified, isFalse);
      expect(restored.identity, isNull);
    });

    test('a reason from a newer build still reads as unverified', () {
      final restored = PmcsSignature.fromMap(
        const {'verified': false, 'blockedBy': 'someFutureReason'},
      )!;

      expect(restored.isVerified, isFalse);
      expect(restored.blockedBy, isNotNull);
    });

    test('an identity missing its DoD ID is not an identity', () {
      final restored = PmcsSignature.fromMap({
        'verified': true,
        'identity': const {'firstName': 'JOHN', 'lastName': 'SMITH'},
        'signedAt': DateTime.utc(2026).toIso8601String(),
      })!;

      expect(restored.isVerified, isFalse);
    });

    test('a verified signature carries no date of birth onto the wire', () {
      expect(buildSignature().toMap().toString(), isNot(contains('1980')));
    });
  });
}
