import 'package:ivy_pulse/data/catalog/jltv_pmcs_catalog.g.dart';
import 'package:ivy_pulse/data/catalog/stryker_pmcs_catalog.g.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';

/// Serves the transcribed TM catalogs compiled into the app.
///
/// The catalogs ship with the binary because a PMCS is walked in a motor pool
/// or on a tactical assembly area with no data — the checklist can never
/// depend on the net being up.
class StaticPmcsCatalogSource implements PmcsCatalogSource {
  /// Platforms this build carries a TM transcription for.
  static const Map<VehicleType, PmcsCatalog> defaultCatalogs = {
    VehicleType.stryker: strykerPmcsCatalog,
    VehicleType.jltv: jltvPmcsCatalog,
  };

  final Map<VehicleType, PmcsCatalog> _catalogs;

  const StaticPmcsCatalogSource({Map<VehicleType, PmcsCatalog>? catalogs})
      : _catalogs = catalogs ?? defaultCatalogs;

  /// Ordered by [VehicleType.values] rather than by map insertion so the
  /// platform picker is stable no matter how the catalogs were registered.
  @override
  List<VehicleType> get supportedVehicles => [
        for (final vehicleType in VehicleType.values)
          if (_catalogs.containsKey(vehicleType)) vehicleType,
      ];

  @override
  PmcsCatalog catalogFor(VehicleType vehicleType) {
    final catalog = _catalogs[vehicleType];
    if (catalog == null) {
      throw StateError(
          'No PMCS catalog registered for ${vehicleType.displayName} '
          '(${vehicleType.wireName}) — register one before starting a session');
    }
    return catalog;
  }
}
