import 'dart:convert';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/services/report_codec.dart';

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
        if (report.maintainerReview != null)
          'maintainerReview': report.maintainerReview!.toMap(),
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
        uic: body['uic'] as String? ?? body['unit'] as String? ?? '',
        phases: _decodePhases(body['phases']),
        faults: _decodeFaults(entityId, body['faults']),
        signature: _decodeSignature(body['signature']),
        maintainerReview: body['maintainerReview'] == null
            ? null
            : MaintainerReview.fromMap(
                (body['maintainerReview'] as Map).cast<String, Object?>()),
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

PmcsSignature? _decodeSignature(Object? raw) {
  if (raw is! Map) return null;
  try {
    return PmcsSignature.fromMap(raw.cast<String, Object?>());
  } catch (_) {
    return null;
  }
}

List<PmcsFault> _decodeFaults(String entityId, Object? raw) {
  if (raw is! List) return const [];
  final faults = <PmcsFault>[];
  for (final value in raw) {
    if (value is! Map) continue;
    faults.add(PmcsFault.fromMap(entityId, value.cast<String, Object?>()));
  }
  return faults;
}
