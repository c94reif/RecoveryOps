import 'package:circle_x/domain/catalog/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/catalog/entities/vehicle_type.dart';

abstract class PmcsCatalogSource {
  List<VehicleType> get supportedVehicles;

  PmcsCatalog catalogFor(VehicleType vehicleType);
}
