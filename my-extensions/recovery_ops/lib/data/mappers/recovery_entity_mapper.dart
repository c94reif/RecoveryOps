import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recovery_report.dart';

class RecoveryEntityMapper {
  static const dataType = 'RECOVERY_REQUEST';

  final String integrationName;

  const RecoveryEntityMapper({this.integrationName = 'recovery_ops'});

  sdk.Entity buildEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    LatLng? navigatorPosition,
    List<LatLng>? routeGeometry,
  }) {
    final now = DateTime.now().toUtc();
    final expiry = now.add(const Duration(days: 1));

    final recoveryData = <String, dynamic>{
      'bumperNumber': bumperNumber,
      'issue': issue,
      'recoveryType': typeName,
      'vehicleLatitude': vehiclePosition.latitude,
      'vehicleLongitude': vehiclePosition.longitude,
      'navigatorLatitude': navigatorPosition?.latitude,
      'navigatorLongitude': navigatorPosition?.longitude,
      'routeGeometry':
          routeGeometry?.map((p) => [p.latitude, p.longitude]).toList(),
    };

    return sdk.Entity(
      id: entityId,
      name: '$bumperNumber - $typeName Recovery',
      lat: vehiclePosition.latitude,
      lon: vehiclePosition.longitude,
      disposition: sdk.Disposition.friendly,
      description: jsonEncode(recoveryData),
      environment: 'land',
      ontology: sdk.EntityOntology(
        platformType: 'Recovery Vehicle',
        specificType: typeName,
        template: 'TEMPLATE_ASSET',
      ),
      provenance: sdk.EntityProvenance(
        integrationName: integrationName,
        dataType: dataType,
        sourceUpdateTime: now.toIso8601String(),
        sourceId: entityId,
      ),
      status: sdk.EntityStatus(
        platformActivity: 'Recovery Request',
        role: typeName,
      ),
      alternateIds: [
        sdk.AlternateId(id: entityId, type: 'ALT_ID_TYPE_ASSET_ID'),
      ],
      createdTime: now,
      expiryTime: expiry,
      isLive: true,
      routeDetails: navigatorPosition != null
          ? {'destinationName': '$bumperNumber - $typeName'}
          : null,
    );
  }

  bool isOwnedRecoveryEntity(sdk.Entity entity) {
    return entity.provenance?.integrationName == integrationName &&
        entity.provenance?.dataType == dataType;
  }

  RecoveryReport? parseRemoteEntity(sdk.Entity entity) {
    if (entity.description == null) return null;
    try {
      final data = jsonDecode(entity.description!) as Map<String, dynamic>;
      final bumperNumber = data['bumperNumber'] as String?;
      final issue = data['issue'] as String?;
      final recoveryType = data['recoveryType'] as String?;
      final vehicleLat = (data['vehicleLatitude'] as num?)?.toDouble();
      final vehicleLon = (data['vehicleLongitude'] as num?)?.toDouble();
      if (bumperNumber == null ||
          issue == null ||
          recoveryType == null ||
          vehicleLat == null ||
          vehicleLon == null) {
        return null;
      }

      return RecoveryReport(
        entityId: entity.id,
        fromCallsign: 'Mesh',
        bumperNumber: bumperNumber,
        issue: issue,
        recoveryType: recoveryType,
        latitude: vehicleLat,
        longitude: vehicleLon,
        navigatorLatitude: (data['navigatorLatitude'] as num?)?.toDouble(),
        navigatorLongitude: (data['navigatorLongitude'] as num?)?.toDouble(),
        routeGeometry: _decodeGeometry(data['routeGeometry']),
        timestamp: entity.createdTime ?? DateTime.now().toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  List<LatLng>? extractGeometry(sdk.Entity entity) {
    if (entity.description == null) return null;
    try {
      final data = jsonDecode(entity.description!) as Map<String, dynamic>;
      return _decodeGeometry(data['routeGeometry']);
    } catch (_) {
      return null;
    }
  }
}

List<LatLng>? _decodeGeometry(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  return raw
      .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();
}
