import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/taticalMarker.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';

class HomeViewModel extends ChangeNotifier {
  final LocationRepository locationRepository;

  HomeViewModel(this.locationRepository);

  int pageIndex = 0;

  final List<TacticalMarker> markers = [];

  static const List<String> pageTitles = ['Recovery', 'Reports', 'Nav', 'Profile'];

  void selectTab(int index) {
    pageIndex = index;
    notifyListeners();
  }

  void addMarker(TacticalMarker marker) {
    markers.add(marker);
    notifyListeners();
  }

  Future<LatLng?> getInitialLocation() async {
    return locationRepository.getCurrentLocation();
  }

  void onMapLongPress(LatLng point) {
    final callsign = 'MKR-${markers.length + 1}';
    addMarker(TacticalMarker(
      position: point,
      callsign: callsign,
      uid: 'recovery_ops-${DateTime.now().millisecondsSinceEpoch}',
    ));
  }
}
