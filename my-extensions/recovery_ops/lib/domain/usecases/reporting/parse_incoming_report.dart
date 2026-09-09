import 'dart:convert';

import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recovery_report.dart';

class ParseIncomingReport {
  RecoveryReport? call(sdk.IncomingMessage msg) {
    try {
      final data = jsonDecode(msg.payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type != 'recovery_request') return null;

      final entityId = data['entityId'] as String?;
      if (entityId == null || entityId.isEmpty) return null;

      return RecoveryReport(
        entityId: entityId,
        fromCallsign: msg.fromCallsign,
        bumperNumber: data['bumperNumber'] as String,
        issue: data['issue'] as String,
        recoveryType: data['recoveryType'] as String,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(data['timestamp'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
