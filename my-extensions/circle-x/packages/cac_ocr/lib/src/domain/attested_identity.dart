import 'package:cac_ocr/src/domain/dod_id.dart';

enum AttestedIdentityError {
  lastNameMissing('Last name is required'),
  firstNameMissing('First name is required'),
  notTenDigits('DoD ID is the 10-digit number on the card'),
  notIssued('That is not a DoD ID number');

  const AttestedIdentityError(this.message);

  final String message;
}

class AttestedIdentity {
  final String dodId;
  final String firstName;
  final String lastName;

  const AttestedIdentity({
    required this.dodId,
    required this.firstName,
    required this.lastName,
  });

  String get displayName => '$lastName, $firstName';

  static ({AttestedIdentity? identity, AttestedIdentityError? error}) parse({
    required String lastName,
    required String firstName,
    required String dodId,
  }) {
    final surname = normalizeName(lastName);
    final given = normalizeName(firstName);
    final digits = DodId.digitsOf(dodId);
    if (surname.isEmpty) return _refused(AttestedIdentityError.lastNameMissing);
    if (given.isEmpty) return _refused(AttestedIdentityError.firstNameMissing);
    if (digits.length != DodId.length) {
      return _refused(AttestedIdentityError.notTenDigits);
    }
    if (!DodId.isIssued(int.parse(digits))) {
      return _refused(AttestedIdentityError.notIssued);
    }
    return (
      identity:
          AttestedIdentity(dodId: digits, firstName: given, lastName: surname),
      error: null,
    );
  }

  static ({AttestedIdentity? identity, AttestedIdentityError? error}) _refused(
          AttestedIdentityError error) =>
      (identity: null, error: error);

  static String normalizeName(String name) =>
      name.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, Object?> toMap() => {
        'edipi': dodId,
        'firstName': firstName,
        'lastName': lastName,
      };

  static AttestedIdentity? fromMap(Map<String, Object?> map) {
    final dodId = map['edipi'];
    final firstName = map['firstName'];
    final lastName = map['lastName'];
    if (!DodId.isValid(dodId) ||
        firstName is! String ||
        firstName.trim().isEmpty ||
        lastName is! String ||
        lastName.trim().isEmpty) {
      return null;
    }
    return AttestedIdentity(
      dodId: dodId as String,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
