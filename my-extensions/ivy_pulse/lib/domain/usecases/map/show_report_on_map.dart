import 'package:flutter/foundation.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Drops the vehicle on the common operating picture, tinted by whether it is
/// mission capable, and centres the map on it.
class ShowReportOnMap {
  final sdk.MapService mapService;

  const ShowReportOnMap(this.mapService);

  Future<String?> call(PmcsReport report, {String? previousMarkerId}) async {
    try {
      if (previousMarkerId != null) {
        await mapService.removeMarker(previousMarkerId);
      }

      final position = sdk.LatLng(report.latitude, report.longitude);
      final markerId = await mapService.addMarker(
        position,
        label: '${report.bumperNumber} — ${report.statusLabel}',
        icon: sdk.MarkerIcon.vehicle,
        disposition: report.isDeadlined
            ? sdk.MarkerDisposition.hostile
            : sdk.MarkerDisposition.friendly,
      );

      await mapService.flyTo(position, zoom: 15);
      return markerId;
    } catch (e) {
      debugPrint('[IvyPulse] ShowReportOnMap error: $e');
      return null;
    }
  }

  Future<void> clear(String markerId) async {
    try {
      await mapService.removeMarker(markerId);
    } catch (e) {
      debugPrint('[IvyPulse] ShowReportOnMap clear error: $e');
    }
  }
}
