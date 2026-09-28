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

class PmcsSession {
  final int? id;

  final String sessionId;
  final String bumperNumber;
  final VehicleType vehicleType;
  final String operator;

  final String uic;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final List<PmcsPhase> completedPhases;
  final SessionStatus status;

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
        for (final completedPhase in PmcsPhase.values)
          if (completedPhase == phase ||
              completedPhases.contains(completedPhase))
            completedPhase,
      ],
    );
  }
}
