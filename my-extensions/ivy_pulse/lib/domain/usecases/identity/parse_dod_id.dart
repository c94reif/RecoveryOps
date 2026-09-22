import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

/// Turns a DoD ID number read off the back of a CAC into the Soldier who is
/// signing.
///
/// The back of the card carries the number and nothing else a signature
/// block needs — no name, no rank — so the identity this produces names the
/// Soldier by number alone and [CacIdentity.displayName] prints it as
/// `DoD ID 1087987498`. That is still a stronger attribution than a typed
/// name: it was read off a card in the operator's hand, and it is the key a
/// maintainer can look up.
///
/// The range check is the one [ParseCacBarcode] applies to a scanned
/// barcode. DEERS has never issued a number outside it, so a value outside it
/// is OCR misreading a digit, and the honest answer is "not a CAC number",
/// not a Soldier who does not exist.
class ParseDodId {
  final Clock clock;

  const ParseDodId(this.clock);

  /// Exactly ten digits.
  static final RegExp _tenDigits = RegExp(r'^\d{10}$');

  CacScan call(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!_tenDigits.hasMatch(digits)) {
      return const CacScan.rejected(CacRejection.notACac);
    }
    final value = int.parse(digits);
    if (value < ParseCacBarcode.lowestEdipi ||
        value > ParseCacBarcode.highestEdipi) {
      return const CacScan.rejected(CacRejection.notACac);
    }
    return CacScan.verified(CacIdentity(
      edipi: digits,
      firstName: '',
      lastName: '',
      verifiedAt: clock.nowUtc(),
    ));
  }
}
