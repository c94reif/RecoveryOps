import 'dart:convert';
import 'package:circle_x/domain/entities/report_message_type.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';

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

  bool get isWithdrawal {
    try {
      final body = jsonDecode(payload);
      return body is Map &&
          body['type'] == ReportMessageType.deletion &&
          body['entityId'] == entityId;
    } catch (_) {
      return false;
    }
  }

  String get summary =>
      '${isWithdrawal ? 'Withdraw ' : isMaintainerReview ? 'Maintainer review: ' : ''}$bumperNumber - $vehicleType';

  bool get isMaintainerReview {
    try {
      final body = jsonDecode(payload);
      return body is Map && body['maintainerReview'] is Map;
    } catch (_) {
      return false;
    }
  }

  String get faultSummary {
    if (faultCount == 0) return 'No faults';
    if (redXCount == 0) return '$faultCount fault(s)';
    return '$faultCount fault(s), $redXCount RED X';
  }
}
