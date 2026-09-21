import 'package:flutter/foundation.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';

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

  /// One peer that heard us is enough — the maintainer's EUD relays the rest.
  Future<bool> _broadcast(String payload, String label) async {
    try {
      final report = await _messaging.broadcast(payload);
      debugPrint('[IvyPulse] Mesh $label: '
          '${report.successCount} delivered, ${report.failureCount} failed');
      return report.successCount > 0;
    } catch (e) {
      debugPrint('[IvyPulse] Mesh $label error: $e');
      return false;
    }
  }
}
