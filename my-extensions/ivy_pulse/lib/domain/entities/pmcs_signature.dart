import 'package:ivy_pulse/domain/entities/attested_identity.dart';
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

  /// Who the operator typed in after the scan failed, or null when they sent
  /// it with no name at all. Only ever set on an unverified signature: a
  /// typed name is a claim the app could not check, and it stays one however
  /// carefully it was entered. What it buys the maintainer is a 5988-E that
  /// can be chased instead of one signed by nobody.
  final AttestedIdentity? attestedBy;

  /// When the PMCS was signed, which is when submit was pressed — not when a
  /// queued leg finally drained.
  final DateTime signedAt;

  const PmcsSignature.verified({
    required CacIdentity this.identity,
    required this.signedAt,
  })  : blockedBy = null,
        attestedBy = null;

  /// [attestedBy] is the typed fallback — see [AttestedIdentity]. Passing it
  /// does not change what this constructor produces: still unverified, still
  /// carrying the reason the scan could not happen.
  const PmcsSignature.unverified({
    required CacRejection this.blockedBy,
    required this.signedAt,
    this.attestedBy,
  }) : identity = null;

  bool get isVerified => identity != null;

  /// How the name got onto the report: `cac` read off the card, `typed` by
  /// the operator after the scan failed, `none` when it went out unsigned.
  /// This is the field a maintainer's trust decision is made on — the
  /// verified flag says whether a card was read, this says what stands in
  /// its place when one was not.
  String get method => switch ((identity, attestedBy)) {
        (CacIdentity(), _) => 'cac',
        (null, AttestedIdentity()) => 'typed',
        _ => 'none',
      };

  /// The DoD ID number behind the name, scanned or typed. Null on a report
  /// that went out with neither.
  String? get dodId => identity?.edipi ?? attestedBy?.edipi;

  /// What goes in the operator column — the name off the card, the name the
  /// operator typed, or a label that cannot be mistaken for either.
  String get displayName =>
      identity?.displayName ?? attestedBy?.displayName ?? 'UNVERIFIED';

  /// Plain-language reason an unverified PMCS went out unsigned. Empty when
  /// the signature is verified.
  String get blockedReason => blockedBy?.message ?? '';

  Map<String, Object?> toMap() => {
        'verified': isVerified,
        if (identity != null) 'identity': identity!.toMap(),
        if (blockedBy != null) 'blockedBy': blockedBy!.name,
        if (attestedBy != null) 'attestedBy': attestedBy!.toMap(),
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

    // A typed name rides along with the unverified signature and never
    // upgrades it — a build that does not know the field reads the same
    // report as plain UNVERIFIED, which is the right direction to fail in.
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
