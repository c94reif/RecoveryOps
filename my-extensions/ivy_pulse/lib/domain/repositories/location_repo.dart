import 'package:latlong2/latlong.dart' as latlong;

abstract class LocationRepository {
  /// Current GPS fix, or null when the host bridge is unavailable, denied, or
  /// slow enough that the operator should not be made to wait.
  Future<latlong.LatLng?> getCurrentLocation();
}
