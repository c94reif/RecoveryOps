import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/mappers/navigator_payload_codec.dart';
import 'package:recovery_ops/data/mappers/recovery_request_payload_codec.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';

class SdkMeshBroadcaster implements MeshBroadcasterPort {
  final sdk.MessagingService _messaging;
  final RecoveryRequestPayloadCodec _requestCodec;
  final NavigatorPayloadCodec _navigatorCodec;

  SdkMeshBroadcaster({
    required sdk.MessagingService messaging,
    RecoveryRequestPayloadCodec? requestCodec,
    NavigatorPayloadCodec? navigatorCodec,
  })  : _messaging = messaging,
        _requestCodec = requestCodec ?? RecoveryRequestPayloadCodec(),
        _navigatorCodec = navigatorCodec ?? NavigatorPayloadCodec();

  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    try {
      final report = await _messaging.broadcast(
        _requestCodec.encodeRecoveryRequest(
          entityId: entityId,
          bumperNumber: bumperNumber,
          issue: issue,
          typeName: typeName,
          position: position,
        ),
      );
      debugPrint('[RecoveryOps] Mesh broadcast: '
          '${report.successCount} delivered, ${report.failureCount} failed');
      return report.successCount > 0;
    } catch (e) {
      debugPrint('[RecoveryOps] Mesh broadcast error: $e');
      return false;
    }
  }

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async {
    try {
      final report = await _messaging
          .broadcast(_requestCodec.encodeRecoveryDeletion(entityId));
      debugPrint('[RecoveryOps] Deletion mesh: '
          '${report.successCount} delivered, ${report.failureCount} failed');
      return report.successCount > 0;
    } catch (e) {
      debugPrint('[RecoveryOps] Deletion mesh error: $e');
      return false;
    }
  }

  @override
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {
    try {
      await _messaging.broadcast(
        _navigatorCodec.encodeNavigatorUpdate(
          entityId: entityId,
          navigatorPosition: navigatorPosition,
          routeGeometry: routeGeometry,
        ),
      );
      debugPrint('[RecoveryOps] Navigator location broadcasted via Mesh');
    } catch (e) {
      debugPrint('[RecoveryOps] broadcastNavigatorLocation error: $e');
    }
  }

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {
    try {
      await _messaging
          .broadcast(_navigatorCodec.encodeNavigationStopped(entityId));
      debugPrint('[RecoveryOps] Navigation stopped broadcasted via Mesh');
    } catch (e) {
      debugPrint('[RecoveryOps] broadcastNavigationStopped error: $e');
    }
  }
}
