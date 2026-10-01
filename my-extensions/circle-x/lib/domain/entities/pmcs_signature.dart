import 'package:circle_x/domain/entities/attested_identity.dart';
import 'package:circle_x/domain/entities/cac_identity.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

class PmcsSignature {
  final CacIdentity? identity;

  final CacRejection? blockedBy;

  final AttestedIdentity? attestedBy;

  final DateTime signedAt;

  const PmcsSignature.verified({
    required CacIdentity this.identity,
    required this.signedAt,
  })  : blockedBy = null,
        attestedBy = null;

  const PmcsSignature.unverified({
    required CacRejection this.blockedBy,
    required this.signedAt,
    this.attestedBy,
  }) : identity = null;

  bool get isVerified => identity != null;

  String get method => switch ((identity, attestedBy)) {
        (CacIdentity(), _) => 'cac',
        (null, AttestedIdentity()) => 'typed',
        _ => 'none',
      };

  String? get dodId => identity?.edipi ?? attestedBy?.edipi;

  String get displayName =>
      identity?.displayName ?? attestedBy?.displayName ?? 'UNVERIFIED';

  String get blockedReason => blockedBy?.message ?? '';

  Map<String, Object?> toMap() => {
        'verified': isVerified,
        if (identity != null) 'identity': identity!.toMap(),
        if (blockedBy != null) 'blockedBy': blockedBy!.name,
        if (attestedBy != null) 'attestedBy': attestedBy!.toMap(),
        'signedAt': signedAt.toUtc().toIso8601String(),
      };

  static PmcsSignature? fromMap(Map<String, Object?> map) {
    final signedAt =
        DateTime.tryParse(map['signedAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final rawIdentity = map['identity'];
    if (rawIdentity is Map) {
      final identity = CacIdentity.fromMap(rawIdentity.cast<String, Object?>());
      if (identity != null) {
        return PmcsSignature.verified(identity: identity, signedAt: signedAt);
      }
    }

    final rawReason = map['blockedBy'];
    final blockedBy = CacRejection.values
        .where((value) => value.name == rawReason)
        .firstOrNull;
    if (blockedBy == null && map['verified'] == null) return null;

    final rawAttested = map['attestedBy'];
    final attestedBy = rawAttested is Map
        ? AttestedIdentity.fromMap(rawAttested.cast<String, Object?>())
        : null;

    return PmcsSignature.unverified(
      blockedBy: blockedBy ?? CacRejection.noCodeFound,
      signedAt: signedAt,
      attestedBy: attestedBy,
    );
  }
}
