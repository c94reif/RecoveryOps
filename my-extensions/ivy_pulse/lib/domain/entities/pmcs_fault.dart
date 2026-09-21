import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';

/// A deficiency raised by a non-serviceable [CheckResult], carrying every
/// field the 5988-E and the maintainer need without re-reading the catalog.
class PmcsFault {
  final int? id;

  /// UUID of the session this fault was found in.
  final String sessionId;

  /// TM item number, e.g. `B-BRK-01`.
  final String itemId;
  final PmcsPhase phase;

  /// Walk-around station or system, e.g. `BRAKES`.
  final String category;

  /// Component name, e.g. `Brake Fluid`.
  final String subcategory;

  /// The TM instruction that was performed.
  final String description;

  /// The condition the operator selected, e.g. `Low`.
  final String condition;
  final FaultSeverity severity;

  /// Optional dictated or typed detail from the operator.
  final String? note;
  final DateTime recordedAt;

  const PmcsFault({
    this.id,
    required this.sessionId,
    required this.itemId,
    required this.phase,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.condition,
    required this.severity,
    this.note,
    required this.recordedAt,
  });

  bool get correctionRequired => severity.requiresCorrection;

  PmcsFault copyWith({int? id, String? note}) => PmcsFault(
        id: id ?? this.id,
        sessionId: sessionId,
        itemId: itemId,
        phase: phase,
        category: category,
        subcategory: subcategory,
        description: description,
        condition: condition,
        severity: severity,
        note: note ?? this.note,
        recordedAt: recordedAt,
      );

  Map<String, Object?> toMap() => {
        'itemId': itemId,
        'phase': phase.wireName,
        'category': category,
        'subcategory': subcategory,
        'description': description,
        'condition': condition,
        'severity': severity.wireName,
        'note': note,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };

  static PmcsFault fromMap(String sessionId, Map<String, Object?> map) {
    return PmcsFault(
      sessionId: sessionId,
      itemId: map['itemId'] as String? ?? '',
      phase: PmcsPhase.tryFromWireName(map['phase'] as String?) ??
          PmcsPhase.before,
      category: map['category'] as String? ?? '',
      subcategory: map['subcategory'] as String? ?? '',
      description: map['description'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      severity: FaultSeverity.tryFromWireName(map['severity'] as String?) ??
          FaultSeverity.dash,
      note: map['note'] as String?,
      recordedAt:
          DateTime.tryParse(map['recordedAt'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// Counts of each severity in a set of faults, for headers and badges.
class FaultTally {
  final int redX;
  final int circleX;
  final int dash;

  const FaultTally({
    this.redX = 0,
    this.circleX = 0,
    this.dash = 0,
  });

  factory FaultTally.from(Iterable<PmcsFault> faults) {
    var redX = 0;
    var circleX = 0;
    var dash = 0;
    for (final fault in faults) {
      switch (fault.severity) {
        case FaultSeverity.redX:
          redX++;
        case FaultSeverity.circleX:
          circleX++;
        case FaultSeverity.dash:
          dash++;
      }
    }
    return FaultTally(redX: redX, circleX: circleX, dash: dash);
  }

  int get total => redX + circleX + dash;
  bool get isEmpty => total == 0;

  /// A vehicle with any RED X is Not Mission Capable.
  bool get isDeadlined => redX > 0;

  FaultSeverity? get worst {
    if (redX > 0) return FaultSeverity.redX;
    if (circleX > 0) return FaultSeverity.circleX;
    if (dash > 0) return FaultSeverity.dash;
    return null;
  }

  /// The vehicle's mission-capable status, as a maintainer reads it off the
  /// 5988-E. Lives here rather than on the report so the summary screen an
  /// operator sees before submitting and the card a maintainer opens after can
  /// never disagree.
  String get missionCapabilityLabel {
    if (isDeadlined) return 'NMC';
    if (circleX > 0) return 'LIMITED';
    if (dash > 0) return 'FMC (DASH)';
    return 'FMC';
  }

  /// The same status spelled out, for the one screen with room for it.
  String get missionCapabilityDetail {
    if (isDeadlined) {
      return 'Not Mission Capable — vehicle is deadlined until maintenance '
          'clears the RED X';
    }
    if (circleX > 0) {
      return 'Mission-essential operation only, with commander approval';
    }
    if (dash > 0) {
      return 'Fully Mission Capable — deferrable deficiencies noted';
    }
    return 'Fully Mission Capable — no deficiencies found';
  }

  int countOf(FaultSeverity severity) => switch (severity) {
        FaultSeverity.redX => redX,
        FaultSeverity.circleX => circleX,
        FaultSeverity.dash => dash,
      };
}
