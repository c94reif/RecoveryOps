import 'package:circle_x/domain/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

abstract class PmcsCatalogSource {
  List<VehicleType> get supportedVehicles;

  PmcsCatalog catalogFor(VehicleType vehicleType);
}
