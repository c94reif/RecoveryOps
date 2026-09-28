import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

abstract class PmcsCatalogSource {
  List<VehicleType> get supportedVehicles;

  PmcsCatalog catalogFor(VehicleType vehicleType);
}
