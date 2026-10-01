import 'package:flutter/foundation.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/services/report_codec.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/mesh_broadcaster_port.dart';

class SdkMeshBroadcaster implements MeshBroadcasterPort {
  final sdk.MessagingService _messaging;
  final ReportCodec _codec;

  SdkMeshBroadcaster({
    required sdk.MessagingService messaging,
    ReportCodec? codec,
  })  : _messaging = messaging,
        _codec = codec ?? const PmcsReportCodec();

  @override
  Future<bool> broadcastPmcsReport(PmcsReport report) {
    return _broadcast(_codec.encodeReport(report), 'broadcast');
  }

  @override
  Future<bool> broadcastEncodedReport(String payload) {
    return _broadcast(payload, 'queued broadcast');
  }

  @override
  Future<bool> broadcastPmcsDeletion(String entityId) {
    return _broadcast(_codec.encodeDeletion(entityId), 'deletion');
  }

  Future<bool> _broadcast(String payload, String label) async {
    try {
      final report = await _messaging.broadcast(payload);
      debugPrint('[CircleX] Mesh $label: '
          '${report.successCount} delivered, ${report.failureCount} failed');
      return report.successCount > 0;
    } catch (error) {
      debugPrint('[CircleX] Mesh $label error: $error');
      return false;
    }
  }
}
