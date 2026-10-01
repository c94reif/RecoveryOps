import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/domain/services/report_map_port.dart';

class SdkReportMapAdapter implements ReportMapPort {
  final sdk.MapService map;

  const SdkReportMapAdapter(this.map);

  @override
  Future<String> addVehicleMarker({
    required double latitude,
    required double longitude,
    required String label,
    required bool isDeadlined,
  }) =>
      map.addMarker(
        sdk.LatLng(latitude, longitude),
        label: label,
        icon: sdk.MarkerIcon.vehicle,
        disposition: isDeadlined
            ? sdk.MarkerDisposition.hostile
            : sdk.MarkerDisposition.friendly,
      );

  @override
  Future<void> removeMarker(String markerId) => map.removeMarker(markerId);

  @override
  Future<void> focusLocation({
    required double latitude,
    required double longitude,
  }) =>
      map.flyTo(sdk.LatLng(latitude, longitude), zoom: 15);
}
