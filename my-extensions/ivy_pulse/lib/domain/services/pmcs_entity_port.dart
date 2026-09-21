import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Publishes PMCS results to the Lattice entity graph so the vehicle shows on
/// the common operating picture with its current mission-capable status.
abstract class PmcsEntityPort {
  /// Upsert the vehicle's PMCS entity. Returns false if the host rejected it
  /// or could not confirm persistence.
  Future<bool> publishPmcsReport(PmcsReport report);

  /// Publish from an already-encoded payload — used when draining the queue,
  /// where the original report object is long gone.
  Future<bool> publishEncodedReport({
    required String entityId,
    required String payload,
    required LatLng position,
  });

  /// Tombstone the entity when a report is withdrawn.
  Future<bool> deletePmcsEntity(String entityId);
}
