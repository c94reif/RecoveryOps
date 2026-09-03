import 'package:recovery_ops/domain/entities/transportKind.dart';

class QueuedRequest {
  final int? id;
  final String entityId;
  final String bumperNumber;
  final String issue;
  final String recoveryType;
  final double latitude;
  final double longitude;
  final TransportKind transport;
  final DateTime createdAt;

  const QueuedRequest({
    this.id,
    required this.entityId,
    required this.bumperNumber,
    required this.issue,
    required this.recoveryType,
    required this.latitude,
    required this.longitude,
    required this.transport,
    required this.createdAt,
  });

  QueuedRequest copyWith({int? id}) => QueuedRequest(
        id: id ?? this.id,
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        recoveryType: recoveryType,
        latitude: latitude,
        longitude: longitude,
        transport: transport,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'entityId': entityId,
        'bumperNumber': bumperNumber,
        'issue': issue,
        'recoveryType': recoveryType,
        'latitude': latitude,
        'longitude': longitude,
        'transport': transport.wireName,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static QueuedRequest fromMap(Map<String, Object?> map) => QueuedRequest(
        id: map['id'] as int?,
        entityId: map['entityId'] as String,
        bumperNumber: map['bumperNumber'] as String,
        issue: map['issue'] as String,
        recoveryType: map['recoveryType'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        transport: TransportKind.fromWireName(map['transport'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
      );

  String get summary => '$bumperNumber - $recoveryType';
}
