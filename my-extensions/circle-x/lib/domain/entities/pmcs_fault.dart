import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';

class PmcsFault {
  final int? id;

  final String sessionId;

  final String itemId;
  final PmcsPhase phase;

  final String category;

  final String subcategory;

  final String description;

  final String condition;
  final FaultSeverity severity;

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

  bool get isDeadlined => redX > 0;

  FaultSeverity? get worst {
    if (redX > 0) return FaultSeverity.redX;
    if (circleX > 0) return FaultSeverity.circleX;
    if (dash > 0) return FaultSeverity.dash;
    return null;
  }

  String get missionCapabilityLabel {
    if (isDeadlined) return 'NMC';
    if (circleX > 0) return 'LIMITED';
    if (dash > 0) return 'FMC (DASH)';
    return 'FMC';
  }

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
