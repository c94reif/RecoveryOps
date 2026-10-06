import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';

class CacScan {
  final CacIdentity? identity;
  final CacRejection? rejection;

  final CacIdentity? expiredCard;

  const CacScan.verified(CacIdentity this.identity)
      : rejection = null,
        expiredCard = null;

  const CacScan.rejected(CacRejection this.rejection)
      : identity = null,
        expiredCard = null;

  const CacScan.expired(CacIdentity this.expiredCard)
      : identity = null,
        rejection = CacRejection.expired;

  factory CacScan.of(CacIdentity card) =>
      card.isCardExpired ? CacScan.expired(card) : CacScan.verified(card);

  bool get isVerified => identity != null;
}
