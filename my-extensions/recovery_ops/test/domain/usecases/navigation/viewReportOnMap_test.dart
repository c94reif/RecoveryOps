import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/viewReportOnMap.dart';

class FakeMapService implements sdk.MapService {
  final List<String> addedMarkerLabels = [];
  final List<String> removedMarkerIds = [];
  final List<String> removedPolylineIds = [];
  final List<sdk.LatLng> flyToLocations = [];
  final List<double?> flyToZooms = [];
  int markerCounter = 0;

  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label, String? color, sdk.MarkerIcon? icon, sdk.MarkerDisposition? disposition}) async {
    addedMarkerLabels.add(label ?? '');
    return 'marker-${markerCounter++}';
  }

  @override
  Future<void> removeMarker(String id) async {
    removedMarkerIds.add(id);
  }

  @override
  Future<void> removePolyline(String id) async {
    removedPolylineIds.add(id);
  }

  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {
    flyToLocations.add(location);
    flyToZooms.add(zoom);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecoveryReport makeReport({
  String bumperNumber = 'HQ-42',
  String recoveryType = 'Wrecker',
  double latitude = 33.0,
  double longitude = -84.0,
}) {
  return RecoveryReport(
    fromCallsign: 'Alpha',
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: recoveryType,
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
  );
}

void main() {
  late FakeMapService map;
  late ViewReportOnMap usecase;

  setUp(() {
    map = FakeMapService();
    usecase = ViewReportOnMap(map);
  });

  test('adds a marker at the report location', () async {
    await usecase.call(makeReport());
    expect(map.addedMarkerLabels, ['HQ-42 - Wrecker']);
  });

  test('flies to the report location with zoom 15', () async {
    await usecase.call(makeReport());
    expect(map.flyToLocations.length, 1);
    expect(map.flyToLocations.first.latitude, 33.0);
    expect(map.flyToLocations.first.longitude, -84.0);
    expect(map.flyToZooms.first, 15);
  });

  test('returns the new marker id', () async {
    final result = await usecase.call(makeReport());
    expect(result.markerId, 'marker-0');
  });

  test('removes previous marker when activeMarkerId is provided', () async {
    await usecase.call(makeReport(), activeMarkerId: 'old-marker');
    expect(map.removedMarkerIds, ['old-marker']);
  });

  test('does not remove marker when activeMarkerId is null', () async {
    await usecase.call(makeReport());
    expect(map.removedMarkerIds, isEmpty);
  });

  test('removes previous polyline when activeRouteId is non-empty', () async {
    await usecase.call(makeReport(), activeRouteId: 'old-route');
    expect(map.removedPolylineIds, ['old-route']);
  });

  test('does not remove polyline when activeRouteId is empty', () async {
    await usecase.call(makeReport(), activeRouteId: '');
    expect(map.removedPolylineIds, isEmpty);
  });
}
