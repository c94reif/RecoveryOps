import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

class ParseDodId {
  final Clock clock;

  const ParseDodId(this.clock);

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
