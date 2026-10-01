// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/tm_source/catalog-manifest.mjs
// Regenerate with ./tool/generate_catalog.sh.

import 'package:circle_x/domain/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'stryker_pmcs_catalog.g.dart';
import 'jltv_pmcs_catalog.g.dart';

const Map<VehicleType, PmcsCatalog> registeredPmcsCatalogs = {
  VehicleType.stryker: strykerPmcsCatalog,
  VehicleType.jltv: jltvPmcsCatalog,
};
