import 'package:latlong2/latlong.dart' as latlong;

abstract class LocationRepository {
  Future<latlong.LatLng?> getCurrentLocation();
}
