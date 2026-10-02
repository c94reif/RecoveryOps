import 'package:circle_x/domain/entities/cac_identity.dart';
import 'package:circle_x/domain/entities/cac_name.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/clock.dart';

class ParseDodId {
  final Clock clock;

  const ParseDodId(this.clock);

  CacScan call(String raw, {CacName? name}) {
    final digits = raw.trim().replaceAll(RegExp(r'[ \t\u00a0-]+'), '');
    if (!CacIdentity.isValidEdipi(digits)) {
      return const CacScan.rejected(CacRejection.notACac);
    }
    return CacScan.verified(CacIdentity(
      edipi: digits,
      firstName: name?.firstName ?? '',
      lastName: name?.lastName ?? '',
      verifiedAt: clock.nowUtc(),
    ));
  }
}
