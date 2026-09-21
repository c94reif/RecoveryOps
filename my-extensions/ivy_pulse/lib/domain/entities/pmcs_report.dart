import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

/// A completed PMCS submitted to the net — either one this device produced
/// ([isOutgoing]) or one received from another crew over mesh or Lattice.
class PmcsReport {
  final int? id;

  /// UUID shared with the Lattice entity and the mesh payload.
  final String entityId;
  final String fromCallsign;
  final String bumperNumber;
  final VehicleType vehicleType;
  final String operator;

  /// Unit Identification Code the vehicle is signed for under.
  final String uic;

  /// Phases covered by this submission.
  final List<PmcsPhase> phases;
  final List<PmcsFault> faults;

  /// Who signed it off and whether a CAC backed that up. Null on a report
  /// from a build that predates CAC verification — which reads the same way
  /// an unverified signature does, never as a verified one.
  final PmcsSignature? signature;
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
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isOutgoing = false,
    this.isRead = false,
  });

  FaultTally get tally => FaultTally.from(faults);

  /// Not Mission Capable — at least one RED X fault.
  bool get isDeadlined => tally.isDeadlined;

  FaultSeverity? get worstSeverity => tally.worst;

  String get statusLabel => tally.missionCapabilityLabel;

  String get summary => '$bumperNumber - ${vehicleType.displayName}';

  /// True only when a CAC was actually read. A report with no signature at
  /// all counts as unverified, so a maintainer is never shown a green tick
  /// this app cannot stand behind.
  bool get isSignatureVerified => signature?.isVerified ?? false;

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
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
    );
  }
}
