import 'package:ivy_pulse/domain/entities/transport_kind.dart';

/// A PMCS submission that could not reach its transport and is parked in the
/// database until that leg comes back up.
///
/// [payload] is the already-encoded report body, so a resumed submission
/// never has to be rebuilt from a session that may since have changed.
class QueuedSubmission {
  final int? id;
  final String entityId;
  final String bumperNumber;
  final String vehicleType;
  final int redXCount;
  final int faultCount;
  final double latitude;
  final double longitude;
  final String payload;
  final TransportKind transport;
  final DateTime createdAt;

  const QueuedSubmission({
    this.id,
    required this.entityId,
    required this.bumperNumber,
    required this.vehicleType,
    required this.redXCount,
    required this.faultCount,
    required this.latitude,
    required this.longitude,
    required this.payload,
    required this.transport,
    required this.createdAt,
  });

  QueuedSubmission copyWith({int? id}) => QueuedSubmission(
        id: id ?? this.id,
        entityId: entityId,
        bumperNumber: bumperNumber,
        vehicleType: vehicleType,
        redXCount: redXCount,
        faultCount: faultCount,
        latitude: latitude,
        longitude: longitude,
        payload: payload,
        transport: transport,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'entityId': entityId,
        'bumperNumber': bumperNumber,
        'vehicleType': vehicleType,
        'redXCount': redXCount,
        'faultCount': faultCount,
        'latitude': latitude,
        'longitude': longitude,
        'payload': payload,
        'transport': transport.wireName,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static QueuedSubmission fromMap(Map<String, Object?> map) => QueuedSubmission(
        id: map['id'] as int?,
        entityId: map['entityId'] as String,
        bumperNumber: map['bumperNumber'] as String,
        vehicleType: map['vehicleType'] as String,
        redXCount: (map['redXCount'] as num?)?.toInt() ?? 0,
        faultCount: (map['faultCount'] as num?)?.toInt() ?? 0,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        payload: map['payload'] as String,
        transport: TransportKind.fromWireName(map['transport'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
      );

  String get summary => '$bumperNumber - $vehicleType';

  String get faultSummary {
    if (faultCount == 0) return 'No faults';
    if (redXCount == 0) return '$faultCount fault(s)';
    return '$faultCount fault(s), $redXCount RED X';
  }
}
