import 'package:flutter/foundation.dart';
import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/domain/repositories/location_repo.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:le_sdk/le_sdk.dart' as sdk;

class LocationRepoImpl implements LocationRepository {
  final sdk.LocationService locationService;

  LocationRepoImpl(this.locationService);

  @override
  Future<latlong.LatLng?> getCurrentLocation() async {
    final result = await locationService.getCurrentLocation().timeout(
      AppConstants.locationTimeout,
      onTimeout: () {
        debugPrint('[CircleX] getCurrentLocation timed out after '
            '${AppConstants.locationTimeout.inSeconds}s — host location bridge '
            'did not respond; proceeding without location');
        return null;
      },
    );
    if (result == null) return null;
    return latlong.LatLng(result.latitude, result.longitude);
  }
}
