import 'package:ivy_pulse/domain/entities/cac_identity.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';

/// Who closed a PMCS out, and whether their CAC actually backed it up.
///
/// A PMCS is signed one of two ways. The normal one is [PmcsSignature.verified]
/// — the Soldier scanned the front of their CAC at the moment they submitted,
/// and the identity travelled with the report. The other is
/// [PmcsSignature.unverified]: the scan could not happen, the operator chose
/// to send it anyway, and the reason rides along so a maintainer reading the
/// card knows this one is a claim with nothing behind it.
///
/// There is deliberately no third state. A report either carries a scan or
/// says out loud that it does not.
class PmcsSignature {
  /// The Soldier off the card. Null is the whole meaning of unverified.
  final CacIdentity? identity;

  /// Why there is no identity — no camera, unreadable code, expired card.
  /// Null on a verified signature.
  final CacRejection? blockedBy;

  /// When the PMCS was signed, which is when submit was pressed — not when a
  /// queued leg finally drained.
  final DateTime signedAt;

  const PmcsSignature.verified({
    required CacIdentity this.identity,
    required this.signedAt,
  }) : blockedBy = null;

  const PmcsSignature.unverified({
    required CacRejection this.blockedBy,
    required this.signedAt,
  }) : identity = null;

  bool get isVerified => identity != null;

  /// What goes in the operator column — the name off the card, or a label
  /// that cannot be mistaken for one.
  String get displayName => identity?.displayName ?? 'UNVERIFIED';

  /// Plain-language reason an unverified PMCS went out unsigned. Empty when
  /// the signature is verified.
  String get blockedReason => blockedBy?.message ?? '';

  Map<String, Object?> toMap() => {
        'verified': isVerified,
        if (identity != null) 'identity': identity!.toMap(),
        if (blockedBy != null) 'blockedBy': blockedBy!.name,
        'signedAt': signedAt.toUtc().toIso8601String(),
      };

  /// Null when the blob holds no usable signature at all — a report from a
  /// build that predates CAC verification, or one whose payload is garbled.
  /// A caller treats null the same way it treats an unverified signature, so
  /// nothing is ever silently promoted to signed.
  static PmcsSignature? fromMap(Map<String, Object?> map) {
    final signedAt =
        DateTime.tryParse(map['signedAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final rawIdentity = map['identity'];
    if (rawIdentity is Map) {
      final identity =
          CacIdentity.fromMap(rawIdentity.cast<String, Object?>());
      if (identity != null) {
        return PmcsSignature.verified(identity: identity, signedAt: signedAt);
      }
    }

    // No identity, so this is unverified whatever the blob claims. A reason
    // this build does not recognise still means "not verified" — falling back
    // to `noCodeFound` would invent a story, so an unknown reason reads as the
    // most honest one available.
    final rawReason = map['blockedBy'];
    final blockedBy = CacRejection.values
        .where((value) => value.name == rawReason)
        .firstOrNull;
    if (blockedBy == null && map['verified'] == null) return null;

    return PmcsSignature.unverified(
      blockedBy: blockedBy ?? CacRejection.noCodeFound,
      signedAt: signedAt,
    );
  }
}
