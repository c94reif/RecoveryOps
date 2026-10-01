import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

class PmcsReport {
  final int? id;

  final String entityId;
  final String fromCallsign;
  final String bumperNumber;
  final VehicleType vehicleType;
  final String operator;

  final String uic;

  final List<PmcsPhase> phases;
  final List<PmcsFault> faults;

  final PmcsSignature? signature;
  final MaintainerReview? maintainerReview;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isRead;

  const PmcsReport({
    this.id,
    required this.entityId,
    required this.fromCallsign,
    required this.bumperNumber,
    required this.vehicleType,
    required this.operator,
    required this.uic,
    this.phases = const [],
    this.faults = const [],
    this.signature,
    this.maintainerReview,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isOutgoing = false,
    this.isRead = false,
  });

  FaultTally get tally => FaultTally.from(faults);

  bool get isDeadlined => tally.isDeadlined;

  FaultSeverity? get worstSeverity => tally.worst;

  String get statusLabel => tally.missionCapabilityLabel;

  String get summary => '$bumperNumber - ${vehicleType.displayName}';

  bool get isSignatureVerified => signature?.isVerified ?? false;
  bool get isMaintainerReview => maintainerReview != null;

  PmcsReport copyWith({
    int? id,
    String? fromCallsign,
    List<PmcsFault>? faults,
    bool? isOutgoing,
    bool? isRead,
  }) {
    return PmcsReport(
      id: id ?? this.id,
      entityId: entityId,
      fromCallsign: fromCallsign ?? this.fromCallsign,
      bumperNumber: bumperNumber,
      vehicleType: vehicleType,
      operator: operator,
      uic: uic,
      phases: phases,
      faults: faults ?? this.faults,
      signature: signature,
      maintainerReview: maintainerReview,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
    );
  }
}
