import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/repositories/location_repo.dart';

class LocationRepoImpl implements LocationRepository {
  final sdk.LocationService locationService;

  static const locationTimeout = Duration(seconds: 5);

  LocationRepoImpl(this.locationService);

  @override
  Future<latlong.LatLng?> getCurrentLocation() async {
    final result = await locationService.getCurrentLocation().timeout(
      locationTimeout,
      onTimeout: () {
        debugPrint('[RecoveryOps] getCurrentLocation timed out after '
            '${locationTimeout.inSeconds}s — host location bridge did not '
            'respond; proceeding without location');
        return null;
      },
    );
    if (result == null) return null;
    return latlong.LatLng(result.latitude, result.longitude);
  }
}
