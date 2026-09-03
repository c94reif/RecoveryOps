import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/taticalMarker.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';
import 'package:recovery_ops/presentation/home/homeViewModel.dart';

class FakeLocationRepository implements LocationRepository {
  LatLng? returnValue;

  @override
  Future<LatLng?> getCurrentLocation() async => returnValue;
}

void main() {
  late FakeLocationRepository locationRepo;
  late HomeViewModel vm;

  setUp(() {
    locationRepo = FakeLocationRepository();
    vm = HomeViewModel(locationRepo);
  });

  test('initial pageIndex is 0', () {
    expect(vm.pageIndex, 0);
  });

  test('initial markers list is empty', () {
    expect(vm.markers, isEmpty);
  });

  test('selectTab updates pageIndex and notifies', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.selectTab(1);

    expect(vm.pageIndex, 1);
    expect(notifyCount, 1);
  });

  test('addMarker appends to markers and notifies', () {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    final marker = TacticalMarker(
      position: const LatLng(33.0, -84.0),
      callsign: 'Test',
      uid: 'test-1',
    );
    vm.addMarker(marker);

    expect(vm.markers.length, 1);
    expect(vm.markers.first.callsign, 'Test');
    expect(notifyCount, 1);
  });

  test('getInitialLocation returns location from repository', () async {
    locationRepo.returnValue = const LatLng(40.0, -74.0);

    final result = await vm.getInitialLocation();

    expect(result, isNotNull);
    expect(result!.latitude, 40.0);
    expect(result.longitude, -74.0);
  });

  test('getInitialLocation returns null when location unavailable', () async {
    locationRepo.returnValue = null;

    final result = await vm.getInitialLocation();

    expect(result, isNull);
  });

  test('onMapLongPress adds marker with auto-generated callsign', () {
    vm.onMapLongPress(const LatLng(33.0, -84.0));

    expect(vm.markers.length, 1);
    expect(vm.markers.first.callsign, 'MKR-1');

    vm.onMapLongPress(const LatLng(34.0, -85.0));

    expect(vm.markers.length, 2);
    expect(vm.markers.last.callsign, 'MKR-2');
  });

  test('pageTitles has correct values', () {
    expect(HomeViewModel.pageTitles, ['Recovery', 'Reports', 'Nav', 'Profile']);
  });

  test('selectTab can cycle through all pages', () {
    for (var i = 0; i < HomeViewModel.pageTitles.length; i++) {
      vm.selectTab(i);
      expect(vm.pageIndex, i);
    }
  });

  test('multiple markers accumulate', () {
    for (var i = 0; i < 5; i++) {
      vm.onMapLongPress(LatLng(33.0 + i, -84.0));
    }
    expect(vm.markers.length, 5);
    expect(vm.markers.last.callsign, 'MKR-5');
  });

  test('onMapLongPress stores correct position', () {
    vm.onMapLongPress(const LatLng(45.123, -90.456));
    expect(vm.markers.first.position.latitude, 45.123);
    expect(vm.markers.first.position.longitude, -90.456);
  });
}
