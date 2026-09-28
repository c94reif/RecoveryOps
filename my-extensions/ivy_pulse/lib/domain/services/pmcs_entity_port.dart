import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

abstract class PmcsEntityPort {
  Future<bool> publishPmcsReport(PmcsReport report);

  Future<bool> publishEncodedReport({
    required String entityId,
    required String payload,
    required LatLng position,
  });

  Future<bool> deletePmcsEntity(String entityId);
}
