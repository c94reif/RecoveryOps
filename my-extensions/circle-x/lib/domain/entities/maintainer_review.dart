import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';

class FaultReview {
  final String itemId;
  final PmcsPhase phase;
  final bool verified;
  final String description;

  const FaultReview({
    required this.itemId,
    required this.phase,
    required this.verified,
    this.description = '',
  });

  (PmcsPhase, String) get key => (phase, itemId);

  Map<String, Object?> toMap() => {
        'itemId': itemId,
        'phase': phase.wireName,
        'verified': verified,
        'description': description,
      };

  static FaultReview fromMap(Map<String, Object?> map) => FaultReview(
        itemId: map['itemId'] as String,
        phase: PmcsPhase.fromWireName(map['phase'] as String),
        verified: map['verified'] as bool,
        description: map['description'] as String? ?? '',
      );
}

/// An immutable review batch, carried by its own report record so concurrent
/// reviews never replace the original PMCS or another maintainer's signature.
class MaintainerReview {
  final String sourceReportId;
  final List<FaultReview> faults;
  final PmcsSignature signature;

  MaintainerReview({
    required this.sourceReportId,
    required List<FaultReview> faults,
    required this.signature,
  }) : faults = List.unmodifiable(faults) {
    if (sourceReportId.isEmpty ||
        !signature.isVerified ||
        !RegExp(r'^\d{10}$').hasMatch(signature.dodId ?? '') ||
        faults.isEmpty ||
        faults.any((fault) => fault.itemId.isEmpty) ||
        faults.map((fault) => fault.key).toSet().length != faults.length) {
      throw ArgumentError('A complete review and CAC signature are required');
    }
  }

  Map<String, Object?> toMap() => {
        'sourceReportId': sourceReportId,
        'faults': [for (final fault in faults) fault.toMap()],
        'signature': signature.toMap(),
      };

  static MaintainerReview fromMap(Map<String, Object?> map) {
    final signature = (map['signature'] as Map).cast<String, Object?>();
    if (signature['verified'] != true ||
        signature['signedAt'] is! String ||
        DateTime.tryParse(signature['signedAt'] as String) == null) {
      throw const FormatException('A CAC-signed review is required');
    }
    return MaintainerReview(
      sourceReportId: map['sourceReportId'] as String,
      faults: [
        for (final fault in map['faults'] as List)
          FaultReview.fromMap((fault as Map).cast<String, Object?>()),
      ],
      signature: PmcsSignature.fromMap(signature)!,
    );
  }
}
