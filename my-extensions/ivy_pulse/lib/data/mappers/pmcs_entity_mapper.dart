import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Shapes a PMCS report into a Lattice entity and back.
///
/// The entity is what puts the vehicle on the common operating picture with
/// its mission-capable status; the full report rides along in the description
/// so a receiving device rebuilds the fault list without a second call.
class PmcsEntityMapper {
  final PmcsReportCodec codec;

  const PmcsEntityMapper({this.codec = const PmcsReportCodec()});

  /// [entityId] overrides the report's own id, for the queue path where the
  /// row the submission was parked under is the id everything else knows.
  sdk.Entity buildEntity(PmcsReport report, {String? entityId}) {
    final now = DateTime.now().toUtc();
    final id = entityId ?? report.entityId;

    return sdk.Entity(
      id: id,
      name: '${report.bumperNumber} — ${report.statusLabel}',
      lat: report.latitude,
      lon: report.longitude,
      // A deadlined vehicle is a hazard to the mission, not an asset the
      // commander can plan around, so it is tinted like a threat on the COP
      // instead of blending in with the rest of the friendly formation.
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

  /// Who signed the PMCS, as top-level fields on the entity.
  ///
  /// The full signature already rides inside the description blob, but that
  /// is a JSON string a Lattice operator sees raw. A maintainer clicking the
  /// vehicle on the COP wants the name and the DoD ID number where the
  /// platform can show them — and an integration keying off the entity wants
  /// them without parsing our report format. `signedBy` is the operator
  /// column as the report card prints it, which on an unverified PMCS reads
  /// `UNVERIFIED` rather than a name the app could not check.
  static Map<String, dynamic> signerFields(PmcsReport report) {
    final signature = report.signature;
    final dodId = signature?.dodId;
    return {
      'signedBy': report.operator,
      'signatureVerified': report.isSignatureVerified,
      // `cac`, `typed` or `none` — a typed name carries a DoD ID too, so the
      // verified flag alone would not tell a consumer which kind it is.
      'signatureMethod': signature?.method ?? 'none',
      if (dodId != null) 'dodId': dodId,
      if (signature != null)
        'signedAt': signature.signedAt.toUtc().toIso8601String(),
    };
  }

  /// Rebuilds an entity from a queued payload, where the report object that
  /// produced it is long gone.
  sdk.Entity buildEntityFromPayload({
    required String entityId,
    required String payload,
    required LatLng position,
  }) {
    final report = codec.decodeReport(payload, fromCallsign: 'Lattice');
    // The queue row's id is authoritative: it is the id the rest of the app
    // and the mesh already know this submission by, and a payload whose body
    // disagreed would publish the vehicle under an id nothing can match.
    if (report != null) return buildEntity(report, entityId: entityId);

    // A payload we can no longer read still has to reach the COP — a pin the
    // maintainer can chase beats the vehicle silently missing from the map.
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
      return codec.reportFromBody(body, fromCallsign: 'Lattice');
    } catch (_) {
      return null;
    }
  }
}
