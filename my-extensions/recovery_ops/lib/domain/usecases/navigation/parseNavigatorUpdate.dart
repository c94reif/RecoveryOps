import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;

class NavigatorUpdate {
  final String entityId;
  final double navigatorLatitude;
  final double navigatorLongitude;
  final List<LatLng>? routeGeometry;
  final bool stopped;

  const NavigatorUpdate({
    required this.entityId,
    required this.navigatorLatitude,
    required this.navigatorLongitude,
    this.routeGeometry,
    this.stopped = false,
  });

  const NavigatorUpdate.stopped({required this.entityId})
      : navigatorLatitude = 0,
        navigatorLongitude = 0,
        routeGeometry = null,
        stopped = true;
}

class ParseNavigatorUpdate {
  NavigatorUpdate? call(sdk.IncomingMessage msg) {
    try {
      final data = jsonDecode(msg.payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'navigation_stopped') {
        return NavigatorUpdate.stopped(
          entityId: data['entityId'] as String,
        );
      }

      if (type != 'navigator_update') return null;

      List<LatLng>? geometry;
      final rawGeometry = data['routeGeometry'] as List<dynamic>?;
      if (rawGeometry != null && rawGeometry.isNotEmpty) {
        geometry = rawGeometry
            .map((p) => LatLng(
                  (p[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                ))
            .toList();
      }

      return NavigatorUpdate(
        entityId: data['entityId'] as String,
        navigatorLatitude: (data['navigatorLatitude'] as num).toDouble(),
        navigatorLongitude: (data['navigatorLongitude'] as num).toDouble(),
        routeGeometry: geometry,
      );
    } catch (_) {
      return null;
    }
  }
}
