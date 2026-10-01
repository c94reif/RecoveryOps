import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';

class PmcsEntityMapper {
  final PmcsReportCodec codec;

  const PmcsEntityMapper({this.codec = const PmcsReportCodec()});

  sdk.Entity buildEntity(PmcsReport report, {String? entityId}) {
    final now = DateTime.now().toUtc();
    final id = entityId ?? report.entityId;

    return sdk.Entity(
      id: id,
      name: '${report.bumperNumber} — ${report.statusLabel}',
      lat: report.latitude,
      lon: report.longitude,
      disposition: report.isDeadlined
          ? sdk.Disposition.hostile
          : sdk.Disposition.friendly,
      description: jsonEncode(codec.reportBody(report)),
      extra: signerFields(report),
      environment: 'land',
      ontology: sdk.EntityOntology(
        platformType: report.vehicleType.displayName,
        specificType: report.statusLabel,
        template: 'TEMPLATE_ASSET',
      ),
      provenance: sdk.EntityProvenance(
        integrationName: AppConstants.extensionId,
        dataType: AppConstants.entityDataType,
        sourceUpdateTime: now.toIso8601String(),
        sourceId: id,
      ),
      status: sdk.EntityStatus(
        platformActivity: 'PMCS',
        role: report.statusLabel,
      ),
      alternateIds: [
        sdk.AlternateId(id: id, type: 'ALT_ID_TYPE_ASSET_ID'),
      ],
      createdTime: now,
      expiryTime: now.add(AppConstants.entityTtl),
      isLive: true,
    );
  }

  static Map<String, dynamic> signerFields(PmcsReport report) {
    final signature = report.signature;
    final dodId = signature?.dodId;
    return {
      'signedBy': report.operator,
      'signatureVerified': report.isSignatureVerified,
      'signatureMethod': signature?.method ?? 'none',
      if (dodId != null) 'dodId': dodId,
      if (signature != null)
        'signedAt': signature.signedAt.toUtc().toIso8601String(),
    };
  }

  sdk.Entity buildEntityFromPayload({
    required String entityId,
    required String payload,
    required LatLng position,
  }) {
    final report = codec.decodeReport(payload, fromCallsign: 'Lattice');
    if (report != null) return buildEntity(report, entityId: entityId);

    final now = DateTime.now().toUtc();
    return sdk.Entity(
      id: entityId,
      name: 'PMCS $entityId',
      lat: position.latitude,
      lon: position.longitude,
      disposition: sdk.Disposition.friendly,
      description: payload,
      environment: 'land',
      ontology: const sdk.EntityOntology(
        platformType: 'Vehicle',
        specificType: 'PMCS',
        template: 'TEMPLATE_ASSET',
      ),
      provenance: sdk.EntityProvenance(
        integrationName: AppConstants.extensionId,
        dataType: AppConstants.entityDataType,
        sourceUpdateTime: now.toIso8601String(),
        sourceId: entityId,
      ),
      status: const sdk.EntityStatus(platformActivity: 'PMCS'),
      alternateIds: [
        sdk.AlternateId(id: entityId, type: 'ALT_ID_TYPE_ASSET_ID'),
      ],
      createdTime: now,
      expiryTime: now.add(AppConstants.entityTtl),
      isLive: true,
    );
  }

  bool isOwnedPmcsEntity(sdk.Entity entity) {
    return entity.provenance?.integrationName == AppConstants.extensionId &&
        entity.provenance?.dataType == AppConstants.entityDataType;
  }

  PmcsReport? parseRemoteEntity(sdk.Entity entity) {
    final description = entity.description;
    if (description == null) return null;
    try {
      final body = jsonDecode(description) as Map<String, Object?>;
      if (body['entityId'] != entity.id) return null;
      return codec.reportFromBody(body, fromCallsign: 'Lattice');
    } catch (_) {
      return null;
    }
  }
}
