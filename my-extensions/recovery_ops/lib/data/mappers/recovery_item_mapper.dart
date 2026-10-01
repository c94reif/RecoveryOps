import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';

class RecoveryItemMapper {
  const RecoveryItemMapper();

  Map<String, Object?> body(
          {required String entityId,
          required String bumperNumber,
          required String issue,
          required String typeName,
          required LatLng position}) =>
      {
        'entityId': entityId,
        'bumperNumber': bumperNumber,
        'issue': issue,
        'recoveryType': typeName,
        'vehicleLatitude': position.latitude,
        'vehicleLongitude': position.longitude,
      };

  RecoveryReport? parse(
      String reportId, Map<String, Object?>? data, DateTime createdAt) {
    if (data == null || data['entityId'] != reportId) return null;
    try {
      return RecoveryReport(
        entityId: reportId,
        fromCallsign: 'Mesh item store',
        bumperNumber: data['bumperNumber'] as String,
        issue: data['issue'] as String,
        recoveryType: data['recoveryType'] as String,
        latitude: (data['vehicleLatitude'] as num).toDouble(),
        longitude: (data['vehicleLongitude'] as num).toDouble(),
        navigatorLatitude: (data['navigatorLatitude'] as num?)?.toDouble(),
        navigatorLongitude: (data['navigatorLongitude'] as num?)?.toDouble(),
        routeGeometry: geometry(data['routeGeometry']),
        timestamp: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  List<LatLng>? geometry(Object? value) {
    if (value is! List || value.isEmpty) return null;
    return [
      for (final point in value)
        LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble())
    ];
  }
}
