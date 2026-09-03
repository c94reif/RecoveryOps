import 'package:latlong2/latlong.dart';

abstract class RecoveryEntityPort {
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  });

  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  });

  Future<bool> deleteRecoveryEntity(String entityId);
}
