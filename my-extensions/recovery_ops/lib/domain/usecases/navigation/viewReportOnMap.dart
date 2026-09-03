import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recoveryReport.dart';

class ViewReportOnMapResult {
  final String? markerId;

  ViewReportOnMapResult({this.markerId});
}

class ViewReportOnMap {
  final sdk.MapService map;

  ViewReportOnMap(this.map);

  Future<ViewReportOnMapResult> call(
    RecoveryReport report, {
    String? activeMarkerId,
    String activeRouteId = '',
  }) async {
    if (activeMarkerId != null) {
      await map.removeMarker(activeMarkerId);
    }
    if (activeRouteId.isNotEmpty) {
      await map.removePolyline(activeRouteId);
    }

    final loc = sdk.LatLng(report.latitude, report.longitude);
    final markerId = await map.addMarker(
      loc,
      label: '${report.bumperNumber} - ${report.recoveryType}',
      icon: sdk.MarkerIcon.vehicle,
      disposition: sdk.MarkerDisposition.friendly,
    );
    await map.flyTo(loc, zoom: 15);

    return ViewReportOnMapResult(markerId: markerId);
  }
}
