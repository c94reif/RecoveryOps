import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';

class NavigatorPayloadCodec {
  String encodeNavigatorUpdate({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) {
    final payload = <String, dynamic>{
      'type': 'navigator_update',
      'entityId': entityId,
      'navigatorLatitude': navigatorPosition.latitude,
      'navigatorLongitude': navigatorPosition.longitude,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    if (routeGeometry != null && routeGeometry.isNotEmpty) {
      payload['routeGeometry'] =
          routeGeometry.map((p) => [p.latitude, p.longitude]).toList();
    }
    return jsonEncode(payload);
  }

  String encodeNavigationStopped(String entityId) {
    return jsonEncode({
      'type': 'navigation_stopped',
      'entityId': entityId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  NavigatorUpdate? parseEntityNavigatorState(sdk.Entity entity) {
    if (entity.description == null) return null;
    try {
      final data = jsonDecode(entity.description!) as Map<String, dynamic>;
      final lat = (data['navigatorLatitude'] as num?)?.toDouble();
      final lng = (data['navigatorLongitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      List<LatLng>? geometry;
      final rawGeometry = data['routeGeometry'] as List?;
      if (rawGeometry != null && rawGeometry.isNotEmpty) {
        geometry = rawGeometry
            .map((p) => LatLng(
                  (p[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                ))
            .toList();
      }

      return NavigatorUpdate(
        entityId: entity.id,
        navigatorLatitude: lat,
        navigatorLongitude: lng,
        routeGeometry: geometry,
      );
    } catch (_) {
      return null;
    }
  }
}
