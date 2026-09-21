import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

/// Supplies the TM check catalog for a vehicle platform.
///
/// Every consumer depends on this abstraction rather than on the generated
/// catalog constants, so a new platform is a registration — not an edit to
/// the inspection flow.
abstract class PmcsCatalogSource {
  /// Platforms this source can supply, in display order.
  List<VehicleType> get supportedVehicles;

  /// The catalog for [vehicleType].
  ///
  /// Throws [StateError] if the platform is not registered — call sites should
  /// only ever pass a value from [supportedVehicles].
  PmcsCatalog catalogFor(VehicleType vehicleType);
}
