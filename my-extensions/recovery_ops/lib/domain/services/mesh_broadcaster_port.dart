import 'package:latlong2/latlong.dart';

abstract class MeshBroadcasterPort {
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  });

  Future<bool> broadcastRecoveryDeletion(String entityId);

  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  });

  Future<void> broadcastNavigationStopped(String entityId);
}
