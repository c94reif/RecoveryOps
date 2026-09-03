import 'dart:convert';

import 'package:latlong2/latlong.dart';

class RecoveryRequestPayloadCodec {
  String encodeRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) {
    return jsonEncode({
      'type': 'recovery_request',
      'entityId': entityId,
      'bumperNumber': bumperNumber,
      'issue': issue,
      'recoveryType': typeName,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  String encodeRecoveryDeletion(String entityId) {
    return jsonEncode({
      'type': 'recovery_request_deleted',
      'entityId': entityId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
