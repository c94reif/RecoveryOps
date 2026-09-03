import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/domain/usecases/navigation/broadcastNavigatorLocation.dart';
import 'package:recovery_ops/domain/usecases/navigation/navigateToReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigationStopped.dart';
import 'package:recovery_ops/domain/usecases/navigation/publishNavigatorEntity.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';

class FakeLocationService implements sdk.LocationService {
  sdk.LatLng? returnValue;

  @override
  Future<sdk.LatLng?> getCurrentLocation() async => returnValue;
}

class FakeMapService implements sdk.MapService {
  final List<String> addedMarkerLabels = [];
  final List<String> removedMarkerIds = [];
  final List<String> addedPolylineIds = [];
  final List<String> removedPolylineIds = [];
  final List<sdk.LatLng> flyToLocations = [];
  int _markerCounter = 0;

  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label,
      String? color,
      sdk.MarkerIcon? icon,
      sdk.MarkerDisposition? disposition}) async {
    addedMarkerLabels.add(label ?? '');
    return 'marker-${_markerCounter++}';
  }

  @override
  Future<void> removeMarker(String id) async {
    removedMarkerIds.add(id);
  }

  @override
  Future<void> addPolyline(String id, List<sdk.LatLng> points,
      {String? color}) async {
    addedPolylineIds.add(id);
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
  @override
  Future<List<RecoveryReport>> getAllReports() async => [];

  @override
  Future<void> insertReport(RecoveryReport report) async {}

  @override
  Future<void> markAsRead(int id) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {}

  @override
  Future<void> clearNavigatorLocation(int id) async {}

  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {}

  @override
  Future<void> deleteReport(int id) async {}
}

class FakeRecoveryEntityPort implements RecoveryEntityPort {
  int navigatorEntityCallCount = 0;

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
    navigatorEntityCallCount++;
    return true;
  }

  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async => true;

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async => true;
}

class FakeMeshBroadcasterPort implements MeshBroadcasterPort {
  int navigatorLocationCallCount = 0;
  int navigationStoppedCallCount = 0;
  LatLng? lastNavigatorPosition;
  String? lastStoppedEntityId;

  @override
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {
    navigatorLocationCallCount++;
    lastNavigatorPosition = navigatorPosition;
  }

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {
    navigationStoppedCallCount++;
    lastStoppedEntityId = entityId;
  }

  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async => true;

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async => true;
}

NavigationViewModel createVm({
  required FakeLocationService location,
  required FakeMapService map,
  required FakeReportsRepository repo,
  FakeRecoveryEntityPort? entityPort,
  FakeMeshBroadcasterPort? meshPort,
}) {
  final ePort = entityPort ?? FakeRecoveryEntityPort();
  final mPort = meshPort ?? FakeMeshBroadcasterPort();
  final broadcast = BroadcastNavigatorLocation(mPort);
  final publishEntity = PublishNavigatorEntity(ePort);
  final publishStopped = PublishNavigationStopped(mPort);
  return NavigationViewModel(
    location,
    NavigateToReport(map, repo, broadcast, publishEntity),
    broadcast,
    publishEntity,
    publishStopped,
  );
}

RecoveryReport makeReport({
  int? id,
  String bumperNumber = 'HQ-42',
  String recoveryType = 'Wrecker',
  String fromCallsign = 'Ghost',
  String issue = 'flat tire',
  double latitude = 33.0,
  double longitude = -84.0,
  bool isOutgoing = false,
}) {
  return RecoveryReport(
    id: id,
    bumperNumber: bumperNumber,
    issue: issue,
    recoveryType: recoveryType,
    fromCallsign: fromCallsign,
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
    isOutgoing: isOutgoing,
  );
}

void main() {
  late FakeLocationService location;
  late FakeMapService map;
  late FakeReportsRepository repo;
  late NavigationViewModel vm;

  setUp(() {
    location = FakeLocationService();
    map = FakeMapService();
    repo = FakeReportsRepository();
    vm = createVm(location: location, map: map, repo: repo);
  });

  tearDown(() {
    vm.dispose();
  });

  group('initial state', () {
    test('currentLocation is null', () {
      expect(vm.currentLocation, isNull);
    });

    test('isNavigating is false', () {
      expect(vm.isNavigating, isFalse);
    });

    test('navigatingReport is null', () {
      expect(vm.navigatingReport, isNull);
    });

    test('hasLocation is false', () {
      expect(vm.hasLocation, isFalse);
    });
  });

  group('refreshLocation', () {
    test('sets currentLocation when location available', () async {
      location.returnValue = const sdk.LatLng(40.0, -74.0);
      await vm.refreshLocation();
      expect(vm.currentLocation, const LatLng(40.0, -74.0));
      expect(vm.hasLocation, isTrue);
    });

    test('does not set location when service returns null', () async {
      location.returnValue = null;
      await vm.refreshLocation();
      expect(vm.hasLocation, isFalse);
    });

    test('notifies listeners when location found', () async {
      location.returnValue = const sdk.LatLng(40.0, -74.0);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.refreshLocation();
      expect(notifyCount, 1);
    });
  });

  group('navigateTo', () {
    test('does nothing when location is unavailable', () async {
      location.returnValue = null;
      final result = await vm.navigateTo(makeReport());
      expect(result, isNull);
      expect(vm.isNavigating, isFalse);
      expect(map.addedMarkerLabels, isEmpty);
    });

    test('sets navigating state when location available', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      final report = makeReport().copyWith(entityId: 'entity-1');
      await vm.navigateTo(report);

      expect(vm.isNavigating, isTrue);
      expect(vm.navigatingReport, isNotNull);
      expect(vm.navigatingReport!.bumperNumber, 'HQ-42');
    });

    test('adds polyline on map', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport());
      expect(map.addedPolylineIds.length, 1);
    });

    test('flies to midpoint', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport());
      expect(map.flyToLocations.length, 1);
      final mid = map.flyToLocations.first;
      expect(mid.latitude, closeTo(33.5, 0.01));
      expect(mid.longitude, closeTo(-84.5, 0.01));
    });

    test('returns the updated report', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      final report = makeReport().copyWith(entityId: 'entity-1');
      final result = await vm.navigateTo(report);

      expect(result, isNotNull);
      expect(result!.bumperNumber, 'HQ-42');
    });

    test('notifies listeners', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.navigateTo(makeReport());
      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('stopNavigation', () {
    test('clears navigating state', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport().copyWith(entityId: 'entity-1'));
      expect(vm.isNavigating, isTrue);

      vm.stopNavigation();
      expect(vm.isNavigating, isFalse);
      expect(vm.navigatingReport, isNull);
    });

    test('notifies listeners', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport().copyWith(entityId: 'entity-1'));

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      vm.stopNavigation();
      expect(notifyCount, 1);
    });

    test('broadcasts navigation_stopped', () async {
      final meshPort = FakeMeshBroadcasterPort();
      final vm = createVm(
        location: location,
        map: map,
        repo: repo,
        meshPort: meshPort,
      );

      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport().copyWith(entityId: 'entity-1'));

      vm.stopNavigation();
      expect(meshPort.navigationStoppedCallCount, 1);
      expect(meshPort.lastStoppedEntityId, 'entity-1');

      vm.dispose();
    });

    test('does not broadcast when not navigating', () {
      final meshPort = FakeMeshBroadcasterPort();
      final vm = createVm(
        location: location,
        map: map,
        repo: repo,
        meshPort: meshPort,
      );

      vm.stopNavigation();
      expect(meshPort.navigationStoppedCallCount, 0);

      vm.dispose();
    });
  });

  group('clearNavigation', () {
    test('clears activeRouteId and navigating state', () async {
      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport().copyWith(entityId: 'entity-1'));

      vm.clearNavigation();
      expect(vm.isNavigating, isFalse);
      expect(vm.navigatingReport, isNull);
      expect(vm.activeRouteId, isEmpty);
    });

    test('broadcasts navigation_stopped', () async {
      final meshPort = FakeMeshBroadcasterPort();
      final vm = createVm(
        location: location,
        map: map,
        repo: repo,
        meshPort: meshPort,
      );

      location.returnValue = const sdk.LatLng(34.0, -85.0);
      await vm.navigateTo(makeReport().copyWith(entityId: 'entity-1'));

      vm.clearNavigation();
      expect(meshPort.navigationStoppedCallCount, 1);
      expect(meshPort.lastStoppedEntityId, 'entity-1');

      vm.dispose();
    });
  });

  group('periodic navigation updates', () {
    test('starts timer after navigateTo', () {
      fakeAsync((async) {
        final meshPort = FakeMeshBroadcasterPort();
        final vm = createVm(
          location: location,
          map: map,
          repo: repo,
          meshPort: meshPort,
        );

        location.returnValue = const sdk.LatLng(34.0, -85.0);
        final report = makeReport(id: 1).copyWith(entityId: 'entity-1');

        vm.navigateTo(report);
        async.flushMicrotasks();

        final initialCount = meshPort.navigatorLocationCallCount;

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(meshPort.navigatorLocationCallCount, greaterThan(initialCount));

        vm.dispose();
      });
    });

    test('stops timer on stopNavigation', () {
      fakeAsync((async) {
        final meshPort = FakeMeshBroadcasterPort();
        final vm = createVm(
          location: location,
          map: map,
          repo: repo,
          meshPort: meshPort,
        );

        location.returnValue = const sdk.LatLng(34.0, -85.0);
        final report = makeReport(id: 1).copyWith(entityId: 'entity-1');

        vm.navigateTo(report);
        async.flushMicrotasks();

        vm.stopNavigation();

        final countAfterStop = meshPort.navigatorLocationCallCount;

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        expect(meshPort.navigatorLocationCallCount, countAfterStop);

        vm.dispose();
      });
    });

    test('stops previous timer when navigating to different report', () {
      fakeAsync((async) {
        final meshPort = FakeMeshBroadcasterPort();
        final vm = createVm(
          location: location,
          map: map,
          repo: repo,
          meshPort: meshPort,
        );

        location.returnValue = const sdk.LatLng(34.0, -85.0);
        final report1 =
            makeReport(id: 1, bumperNumber: 'A').copyWith(entityId: 'entity-1');
        final report2 =
            makeReport(id: 2, bumperNumber: 'B').copyWith(entityId: 'entity-2');

        vm.navigateTo(report1);
        async.flushMicrotasks();

        vm.navigateTo(report2);
        async.flushMicrotasks();

        final countAfterSwitch = meshPort.navigatorLocationCallCount;

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(meshPort.navigatorLocationCallCount, countAfterSwitch + 1);

        vm.dispose();
      });
    });

    test('does not start timer when report has no entityId', () {
      fakeAsync((async) {
        final meshPort = FakeMeshBroadcasterPort();
        final vm = createVm(
          location: location,
          map: map,
          repo: repo,
          meshPort: meshPort,
        );

        location.returnValue = const sdk.LatLng(34.0, -85.0);
        final report = makeReport(id: 1);

        vm.navigateTo(report);
        async.flushMicrotasks();

        final countAfterNav = meshPort.navigatorLocationCallCount;

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        expect(meshPort.navigatorLocationCallCount, countAfterNav);

        vm.dispose();
      });
    });
  });
}
