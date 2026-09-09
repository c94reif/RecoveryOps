import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcast_navigator_location.dart';
import 'package:recovery_ops/domain/usecases/navigation/navigate_to_report.dart';
import 'package:recovery_ops/domain/usecases/navigation/publish_navigator_entity.dart';

class FakeMapService implements sdk.MapService {
  final List<String> addedMarkerLabels = [];
  final List<String> removedMarkerIds = [];
  final List<String> addedPolylineIds = [];
  final List<List<sdk.LatLng>> addedPolylinePoints = [];
  final List<String?> addedPolylineColors = [];
  final List<String> removedPolylineIds = [];
  final List<sdk.LatLng> flyToLocations = [];
  int markerCounter = 0;

  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label,
      String? color,
      sdk.MarkerIcon? icon,
      sdk.MarkerDisposition? disposition}) async {
    addedMarkerLabels.add(label ?? '');
    return 'marker-${markerCounter++}';
  }

  @override
  Future<void> removeMarker(String id) async {
    removedMarkerIds.add(id);
  }

  @override
  Future<void> addPolyline(String id, List<sdk.LatLng> points,
      {String? color}) async {
    addedPolylineIds.add(id);
    addedPolylinePoints.add(points);
    addedPolylineColors.add(color);
  }

  @override
  Future<void> removePolyline(String id) async {
    removedPolylineIds.add(id);
  }

  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {
    flyToLocations.add(location);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReportsRepository implements ReportsRepository {
  int updateNavCallCount = 0;
  int? lastNavId;
  double? lastNavLat;
  double? lastNavLng;

  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {
    updateNavCallCount++;
    lastNavId = id;
    lastNavLat = latitude;
    lastNavLng = longitude;
  }

  @override
  Future<void> clearNavigatorLocation(int id) async {}

  @override
  Future<List<RecoveryReport>> getAllReports() async => [];
  @override
  Future<void> insertReport(RecoveryReport report) async {}
  @override
  Future<void> markAsRead(int id) async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {}
  @override
  Future<void> deleteReport(int id) async {}
}

class FakeRecoveryEntityPort implements RecoveryEntityPort {
  int publishNavCount = 0;

  @override
  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {
    publishNavCount++;
    return true;
  }

  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async =>
      true;

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async => true;
}

class FakeMeshBroadcasterPort implements MeshBroadcasterPort {
  int broadcastNavCount = 0;

  @override
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {
    broadcastNavCount++;
  }

  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async =>
      true;

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async => true;

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {}
}

RecoveryReport makeReport({
  int? id,
  String entityId = '',
  String bumperNumber = 'HQ-42',
  List<LatLng>? routeGeometry,
}) {
  return RecoveryReport(
    id: id,
    entityId: entityId,
    fromCallsign: 'Alpha',
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
    routeGeometry: routeGeometry,
  );
}

void main() {
  late FakeMapService map;
  late FakeReportsRepository repo;
  late FakeRecoveryEntityPort entityPort;
  late FakeMeshBroadcasterPort meshPort;
  late NavigateToReport usecase;

  setUp(() {
    map = FakeMapService();
    repo = FakeReportsRepository();
    entityPort = FakeRecoveryEntityPort();
    meshPort = FakeMeshBroadcasterPort();
    usecase = NavigateToReport(
      map,
      repo,
      BroadcastNavigatorLocation(meshPort),
      PublishNavigatorEntity(entityPort),
    );
  });

  final currentLocation = const LatLng(34.0, -85.0);

  test('draws polyline from origin to destination', () async {
    await usecase.call(makeReport(), currentLocation);
    expect(map.addedPolylineIds.length, 1);
    expect(map.addedPolylinePoints.first.length, 2);
  });

  test('uses green color for straight-line route', () async {
    await usecase.call(makeReport(), currentLocation);
    expect(map.addedPolylineColors.first, '#4A7820');
  });

  test('uses orange color when report has geometry', () async {
    final report = makeReport(routeGeometry: [
      const LatLng(33.0, -84.0),
      const LatLng(33.5, -84.5),
      const LatLng(34.0, -85.0),
    ]);
    await usecase.call(report, currentLocation);
    expect(map.addedPolylineColors.first, '#FF8C00');
  });

  test('uses route geometry points when available', () async {
    final geometry = [
      const LatLng(33.0, -84.0),
      const LatLng(33.5, -84.5),
      const LatLng(34.0, -85.0),
    ];
    final report = makeReport(routeGeometry: geometry);
    await usecase.call(report, currentLocation);
    expect(map.addedPolylinePoints.first.length, 3);
  });

  test('returns a result with route id', () async {
    final result = await usecase.call(makeReport(), currentLocation);
    expect(result.routeId, isNotEmpty);
    expect(result.routeId, startsWith('nav-'));
  });

  test('sets navigator location on the returned report', () async {
    final result = await usecase.call(makeReport(), currentLocation);
    expect(result.updatedReport.navigatorLatitude, 34.0);
    expect(result.updatedReport.navigatorLongitude, -85.0);
  });

  test('persists navigator location when report has an id', () async {
    await usecase.call(makeReport(id: 7), currentLocation);
    expect(repo.updateNavCallCount, 1);
    expect(repo.lastNavId, 7);
    expect(repo.lastNavLat, 34.0);
    expect(repo.lastNavLng, -85.0);
  });

  test('does not persist navigator location when report has no id', () async {
    await usecase.call(makeReport(id: null), currentLocation);
    expect(repo.updateNavCallCount, 0);
  });

  test('publishes navigator location when entityId is present', () async {
    await usecase.call(makeReport(entityId: 'entity-1'), currentLocation);
    await Future.delayed(Duration.zero);
    expect(entityPort.publishNavCount, 1);
    expect(meshPort.broadcastNavCount, 1);
  });

  test('does not publish when entityId is empty', () async {
    await usecase.call(makeReport(entityId: ''), currentLocation);
    await Future.delayed(Duration.zero);
    expect(entityPort.publishNavCount, 0);
    expect(meshPort.broadcastNavCount, 0);
  });

  test('removes previous marker when activeMarkerId is provided', () async {
    await usecase.call(makeReport(), currentLocation, activeMarkerId: 'old');
    expect(map.removedMarkerIds, ['old']);
  });

  test('removes previous polyline when activeRouteId is non-empty', () async {
    await usecase.call(makeReport(), currentLocation,
        activeRouteId: 'old-route');
    expect(map.removedPolylineIds, ['old-route']);
  });

  test('flies to midpoint of the route', () async {
    await usecase.call(makeReport(), currentLocation);
    expect(map.flyToLocations.length, 1);
    final mid = map.flyToLocations.first;
    expect(mid.latitude, closeTo(33.5, 0.01));
    expect(mid.longitude, closeTo(-84.5, 0.01));
  });
}
