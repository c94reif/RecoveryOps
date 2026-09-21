import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

enum SessionStatus {
  inProgress,
  submitted;

  String get wireName => switch (this) {
        SessionStatus.inProgress => 'IN_PROGRESS',
        SessionStatus.submitted => 'SUBMITTED',
      };

  static SessionStatus fromWireName(String value) => switch (value) {
        'IN_PROGRESS' => SessionStatus.inProgress,
        'SUBMITTED' => SessionStatus.submitted,
        _ => throw ArgumentError('Unknown session status: $value'),
      };
}

/// One operator's PMCS of one vehicle. Survives app restarts so a Soldier
/// interrupted mid-walk-around resumes exactly where they stopped.
class PmcsSession {
  final int? id;

  /// UUID; doubles as the Lattice entity id when the session is published.
  final String sessionId;
  final String bumperNumber;
  final VehicleType vehicleType;
  final String operator;

  /// Unit Identification Code the vehicle is signed for under.
  final String uic;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final List<PmcsPhase> completedPhases;
  final SessionStatus status;

  /// Who signed the PMCS off, stamped at submit. Null while the walk-around
  /// is still open — a session started by one Soldier can be closed out by
  /// another, so nobody is assumed until the CAC is read.
  final PmcsSignature? signature;
  final double? latitude;
  final double? longitude;

  const PmcsSession({
    this.id,
    required this.sessionId,
    required this.bumperNumber,
    required this.vehicleType,
    required this.operator,
    required this.uic,
    required this.startedAt,
    this.submittedAt,
    this.completedPhases = const [],
    this.status = SessionStatus.inProgress,
    this.signature,
    this.latitude,
    this.longitude,
  });

  bool isPhaseComplete(PmcsPhase phase) => completedPhases.contains(phase);

  List<PmcsPhase> get remainingPhases =>
      PmcsPhase.values.where((p) => !completedPhases.contains(p)).toList();

  bool get allPhasesComplete => remainingPhases.isEmpty;

  bool get hasStartedAnyPhase => completedPhases.isNotEmpty;

  String get displayTitle => '$bumperNumber - ${vehicleType.displayName}';

  PmcsSession copyWith({
    int? id,
    String? bumperNumber,
    VehicleType? vehicleType,
    String? operator,
    String? uic,
    DateTime? submittedAt,
    List<PmcsPhase>? completedPhases,
    SessionStatus? status,
    PmcsSignature? signature,
    double? latitude,
    double? longitude,
  }) {
    return PmcsSession(
      id: id ?? this.id,
      sessionId: sessionId,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operator: operator ?? this.operator,
      uic: uic ?? this.uic,
      startedAt: startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      completedPhases: completedPhases ?? this.completedPhases,
      status: status ?? this.status,
      signature: signature ?? this.signature,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  PmcsSession withPhaseCompleted(PmcsPhase phase) {
    if (completedPhases.contains(phase)) return this;
    return copyWith(
      completedPhases: [
        for (final p in PmcsPhase.values)
          if (p == phase || completedPhases.contains(p)) p,
      ],
    );
  }
}
