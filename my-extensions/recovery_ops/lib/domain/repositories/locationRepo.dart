import 'package:latlong2/latlong.dart' as profileRepo;

abstract class LocationRepository {
  Future<profileRepo.LatLng?> getCurrentLocation();
}
