import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';

class PublishNavigatorEntity {
  final RecoveryEntityPort entityPort;

  PublishNavigatorEntity(this.entityPort);

  Future<bool> call({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) {
    return entityPort.publishNavigatorEntity(
      entityId: entityId,
      bumperNumber: bumperNumber,
      issue: issue,
      typeName: typeName,
      vehiclePosition: vehiclePosition,
      navigatorPosition: navigatorPosition,
      routeGeometry: routeGeometry,
    );
  }
}
