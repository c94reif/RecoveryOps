import 'dart:convert';

import 'package:le_sdk/le_sdk.dart' as sdk;

class ParseIncomingDeletion {
  String? call(sdk.IncomingMessage msg) {
    try {
      final data = jsonDecode(msg.payload) as Map<String, dynamic>;
      if (data['type'] != 'recovery_request_deleted') return null;
      final entityId = data['entityId'] as String?;
      if (entityId == null || entityId.isEmpty) return null;
      return entityId;
    } catch (_) {
      return null;
    }
  }
}
