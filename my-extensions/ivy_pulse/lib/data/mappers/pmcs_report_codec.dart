import 'dart:convert';

import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/pmcs_signature.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';

/// JSON wire format for a PMCS report.
///
/// The mesh payload and the Lattice entity description carry the exact same
/// body — [reportBody] and [reportFromBody] are shared with the entity mapper
/// so a report received over either transport decodes identically.
class PmcsReportCodec implements ReportCodec {
  const PmcsReportCodec();

  @override
  String encodeReport(PmcsReport report) => jsonEncode(reportBody(report));

  @override
  String encodeDeletion(String entityId) => jsonEncode({
        'type': AppConstants.meshDeletionType,
        'entityId': entityId,
      });

  Map<String, Object?> reportBody(PmcsReport report) => {
        'type': AppConstants.meshReportType,
        'entityId': report.entityId,
        'bumperNumber': report.bumperNumber,
        'vehicleType': report.vehicleType.wireName,
        'operator': report.operator,
        'uic': report.uic,
        'phases': [for (final phase in report.phases) phase.wireName],
        'faults': [for (final fault in report.faults) fault.toMap()],
        if (report.signature != null) 'signature': report.signature!.toMap(),
        'latitude': report.latitude,
        'longitude': report.longitude,
        'timestamp': report.timestamp.toUtc().toIso8601String(),
      };

  @override
  PmcsReport? decodeReport(String payload, {required String fromCallsign}) {
    try {
      final body = jsonDecode(payload) as Map<String, Object?>;
      if (body['type'] != AppConstants.meshReportType) return null;
      return reportFromBody(body, fromCallsign: fromCallsign);
    } catch (_) {
      return null;
    }
  }

  @override
  String? decodeDeletion(String payload) {
    try {
      final body = jsonDecode(payload) as Map<String, Object?>;
      if (body['type'] != AppConstants.meshDeletionType) return null;
      final entityId = body['entityId'] as String?;
      if (entityId == null || entityId.isEmpty) return null;
      return entityId;
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds a report from a decoded body, whatever carried it.
  ///
  /// Identity and position are hard requirements — without them the report
  /// cannot be matched to a vehicle or plotted. Everything else degrades: a
  /// body written by an older build is still worth showing a maintainer.
  PmcsReport? reportFromBody(
    Map<String, Object?> body, {
    required String fromCallsign,
  }) {
    try {
      final entityId = body['entityId'] as String?;
      final bumperNumber = body['bumperNumber'] as String?;
      final vehicleType =
          VehicleType.tryFromWireName(body['vehicleType'] as String?);
      final latitude = (body['latitude'] as num?)?.toDouble();
      final longitude = (body['longitude'] as num?)?.toDouble();
      if (entityId == null ||
          entityId.isEmpty ||
          bumperNumber == null ||
          vehicleType == null ||
          latitude == null ||
          longitude == null) {
        return null;
      }

      return PmcsReport(
        entityId: entityId,
        fromCallsign: fromCallsign,
        bumperNumber: bumperNumber,
        vehicleType: vehicleType,
        operator: body['operator'] as String? ?? '',
        // `unit` is what builds before the UIC-only profile put here. A
        // report from one of those is still worth showing a maintainer.
        uic: body['uic'] as String? ?? body['unit'] as String? ?? '',
        phases: _decodePhases(body['phases']),
        faults: _decodeFaults(entityId, body['faults']),
        signature: _decodeSignature(body['signature']),
        latitude: latitude,
        longitude: longitude,
        timestamp:
            DateTime.tryParse(body['timestamp'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
        isOutgoing: false,
        isRead: false,
      );
    } catch (_) {
      return null;
    }
  }
}

List<PmcsPhase> _decodePhases(Object? raw) {
  if (raw is! List) return const [];
  final phases = <PmcsPhase>[];
  for (final value in raw) {
    final phase = PmcsPhase.tryFromWireName(value is String ? value : null);
    if (phase != null) phases.add(phase);
  }
  return phases;
}

/// A body with no signature block came from a build that predates CAC
/// verification. It decodes to null, which every reader treats as unverified —
/// the one thing that must never happen is an unsigned report arriving as a
/// signed one.
PmcsSignature? _decodeSignature(Object? raw) {
  if (raw is! Map) return null;
  try {
    return PmcsSignature.fromMap(raw.cast<String, Object?>());
  } catch (_) {
    return null;
  }
}

/// The sending device's session id never goes on the wire, so the faults are
/// grouped under the entity id instead — the key both transports share.
List<PmcsFault> _decodeFaults(String entityId, Object? raw) {
  if (raw is! List) return const [];
  final faults = <PmcsFault>[];
  for (final value in raw) {
    if (value is! Map) continue;
    faults.add(PmcsFault.fromMap(entityId, value.cast<String, Object?>()));
  }
  return faults;
}
