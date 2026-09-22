import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

/// Who the operator *says* closed the PMCS out, typed by hand because the
/// CAC could not be read.
///
/// The fallback for a scan that failed — no camera, glare that would not
/// clear, a card the parser refused. The alternative was a report signed by
/// nobody at all, which is worse for the maintainer than a name they have to
/// take on trust: a 5988-E with a name and DoD ID on it can be chased, and
/// one marked UNVERIFIED cannot.
///
/// Deliberately not a [CacIdentity]. That type means "read off the card",
/// carries rank, branch and expiry the card supplied, and is what
/// [PmcsSignature.isVerified] stands on. This one carries the three fields a
/// person can be asked for at a vehicle and nothing the app would have to
/// invent. It never makes a signature verified — see
/// [PmcsSignature.unverified].
class AttestedIdentity {
  /// DoD ID number, ten digits, digits only.
  final String edipi;
  final String firstName;
  final String lastName;

  const AttestedIdentity({
    required this.edipi,
    required this.firstName,
    required this.lastName,
  });

  /// `SMITH, JOHN` — the same shape as the scanned signature block minus the
  /// rank the card would have carried, so the two read alike on a report and
  /// the difference is stated by the verification flag, not by formatting.
  String get displayName => '$lastName, $firstName';

  /// Builds an identity from what the operator typed, or explains why it
  /// will not do. Names are upper-cased and trimmed the way the card prints
  /// them; the DoD ID is stripped of anything that is not a digit before it
  /// is judged, so a number typed with spaces is not refused for the spaces.
  ///
  /// The DoD ID range is the one [ParseCacBarcode] enforces on a scanned
  /// card: DEERS has never issued a number outside it, so a value outside it
  /// is a typo, not a Soldier with an odd id.
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

  /// Null for anything that is not a usable typed identity — a blob from a
  /// newer build with fields this one does not know is still fine; one with
  /// no DoD ID is not.
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
