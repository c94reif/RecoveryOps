import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';

class BroadcastNavigatorLocation {
  final MeshBroadcasterPort meshPort;

  BroadcastNavigatorLocation(this.meshPort);

  Future<void> call({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) {
    return meshPort.broadcastNavigatorLocation(
      entityId: entityId,
      navigatorPosition: navigatorPosition,
      routeGeometry: routeGeometry,
    );
  }
}
