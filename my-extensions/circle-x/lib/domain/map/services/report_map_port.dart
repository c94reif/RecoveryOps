abstract interface class ReportMapPort {
  Future<String> addVehicleMarker({
    required double latitude,
    required double longitude,
    required String label,
    required bool isDeadlined,
  });

  Future<void> removeMarker(String markerId);

  Future<void> focusLocation({
    required double latitude,
    required double longitude,
  });
}
