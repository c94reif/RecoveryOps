import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/attested_identity.dart';

void main() {
  group('a typed identity', () {
    test('what the operator typed is normalised the way the card prints it',
        () {
      final parsed = AttestedIdentity.parse(
        lastName: '  smith ',
        firstName: 'john',
        dodId: '1087 987 498',
      );

      expect(parsed.error, isNull);
      expect(parsed.identity!.lastName, 'SMITH');
      expect(parsed.identity!.firstName, 'JOHN');
      expect(parsed.identity!.dodId, '1087987498');
    });

    test('refuses the entries that cannot be a Soldier', () {
      AttestedIdentityError? errorFor(
              {String last = 'SMITH',
              String first = 'JOHN',
              String id = '1087987498'}) =>
          AttestedIdentity.parse(lastName: last, firstName: first, dodId: id)
              .error;

      expect(errorFor(last: ' '), AttestedIdentityError.lastNameMissing);
      expect(errorFor(first: ''), AttestedIdentityError.firstNameMissing);
      expect(errorFor(id: '12345'), AttestedIdentityError.notTenDigits);
      expect(errorFor(id: '0000000001'), AttestedIdentityError.notIssued);
      expect(errorFor(), isNull);
    });

    test('each refusal says what to fix, in the package wording', () {
      expect(AttestedIdentityError.values.map((error) => error.message), [
        'Last name is required',
        'First name is required',
        'DoD ID is the 10-digit number on the card',
        'That is not a DoD ID number',
      ]);
    });

    test('reads surname first, the way the card prints it', () {
      const typed = AttestedIdentity(
          dodId: '1087987498', firstName: 'JOHN', lastName: 'SMITH');

      expect(typed.displayName, 'SMITH, JOHN');
    });

    test('collapses the spacing a hurried thumb leaves in a name', () {
      expect(
          AttestedIdentity.normalizeName('  van   der  berg '), 'VAN DER BERG');
    });
  });

  group('storage', () {
    test('round-trips what was typed', () {
      const typed = AttestedIdentity(
          dodId: '1087987498', firstName: 'JOHN', lastName: 'SMITH');
      final restored = AttestedIdentity.fromMap(typed.toMap())!;

      expect(restored.dodId, '1087987498');
      expect(restored.displayName, 'SMITH, JOHN');
    });

    test('refuses a record with no usable number or name', () {
      const good = {
        'edipi': '1087987498',
        'firstName': 'JOHN',
        'lastName': 'SMITH',
      };
      for (final broken in <Map<String, Object?>>[
        {...good, 'edipi': '12345'},
        {...good, 'firstName': ' '},
        {...good, 'firstName': 3},
        {...good, 'lastName': ''},
        {...good}..remove('lastName'),
      ]) {
        expect(AttestedIdentity.fromMap(broken), isNull, reason: '$broken');
      }
    });
  });
}
