import 'package:circle_x/domain/usecases/identity/parse_cac_barcode.dart';

class AttestedIdentity {
  final String edipi;
  final String firstName;
  final String lastName;

  const AttestedIdentity({
    required this.edipi,
    required this.firstName,
    required this.lastName,
  });

  String get displayName => '$lastName, $firstName';

  static ({AttestedIdentity? identity, String? error}) parse({
    required String lastName,
    required String firstName,
    required String edipi,
  }) {
    final surname = normalizeName(lastName);
    final given = normalizeName(firstName);
    final digits = edipi.replaceAll(RegExp(r'\D'), '');

    if (surname.isEmpty) {
      return (identity: null, error: 'Last name is required');
    }
    if (given.isEmpty) {
      return (identity: null, error: 'First name is required');
    }
    if (digits.length != 10) {
      return (
        identity: null,
        error: 'DoD ID is the 10-digit number on the card'
      );
    }
    final value = int.parse(digits);
    if (value < ParseCacBarcode.lowestEdipi ||
        value > ParseCacBarcode.highestEdipi) {
      return (identity: null, error: 'That is not a DoD ID number');
    }

    return (
      identity: AttestedIdentity(
        edipi: digits,
        firstName: given,
        lastName: surname,
      ),
      error: null,
    );
  }

  static String normalizeName(String name) =>
      name.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, Object?> toMap() => {
        'edipi': edipi,
        'firstName': firstName,
        'lastName': lastName,
      };

  static AttestedIdentity? fromMap(Map<String, Object?> map) {
    final edipi = map['edipi'];
    if (edipi is! String || edipi.isEmpty) return null;
    return AttestedIdentity(
      edipi: edipi,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
    );
  }
}
