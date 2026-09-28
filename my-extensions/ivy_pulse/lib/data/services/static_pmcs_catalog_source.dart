import 'package:ivy_pulse/data/catalog/jltv_pmcs_catalog.g.dart';
import 'package:ivy_pulse/data/catalog/stryker_pmcs_catalog.g.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';

class StaticPmcsCatalogSource implements PmcsCatalogSource {
  static const Map<VehicleType, PmcsCatalog> defaultCatalogs = {
    VehicleType.stryker: strykerPmcsCatalog,
    VehicleType.jltv: jltvPmcsCatalog,
  };

  final Map<VehicleType, PmcsCatalog> _catalogs;

  const StaticPmcsCatalogSource({Map<VehicleType, PmcsCatalog>? catalogs})
      : _catalogs = catalogs ?? defaultCatalogs;

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
