import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/services/recoveryEntityPort.dart';
import 'package:recovery_ops/domain/services/remoteReportSource.dart';
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';
import 'package:recovery_ops/domain/usecases/reporting/syncLocalReportsToLattice.dart';

class FakeRemoteReportSource implements RemoteReportSource {
  Set<String> knownIds = const {};
  bool shouldThrow = false;
  int fetchKnownCallCount = 0;

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async {
    fetchKnownCallCount++;
    if (shouldThrow) throw Exception('lattice offline');
    return knownIds;
  }

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async => const [];

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async => null;

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async => null;
}

class FakeRecoveryEntityPort implements RecoveryEntityPort {
  final List<({String entityId, String typeName, LatLng position})>
      recoveryUpserts = [];
  final List<
      ({
        String entityId,
        LatLng vehiclePosition,
        LatLng navigatorPosition,
        List<LatLng>? routeGeometry,
      })> navigatorUpserts = [];
  Map<String, bool> publishOkByEntityId = {};
  bool defaultPublishOk = true;

  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    recoveryUpserts.add((entityId: entityId, typeName: typeName, position: position));
    return publishOkByEntityId[entityId] ?? defaultPublishOk;
  }

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
    navigatorUpserts.add((
      entityId: entityId,
      vehiclePosition: vehiclePosition,
      navigatorPosition: navigatorPosition,
      routeGeometry: routeGeometry,
    ));
    return publishOkByEntityId[entityId] ?? defaultPublishOk;
  }

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async => true;
}

RecoveryReport makeReport({
  required String? entityId,
  String bumperNumber = 'HQ-42',
  double? navigatorLatitude,
  double? navigatorLongitude,
  List<LatLng>? routeGeometry,
  bool isOutgoing = true,
}) {
  return RecoveryReport(
    entityId: entityId,
    fromCallsign: 'Alpha',
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 5, 1, 12),
    navigatorLatitude: navigatorLatitude,
    navigatorLongitude: navigatorLongitude,
    routeGeometry: routeGeometry,
    isOutgoing: isOutgoing,
  );
}

void main() {
  late FakeRemoteReportSource source;
  late FakeRecoveryEntityPort entityPort;
  late SyncLocalReportsToLattice usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    entityPort = FakeRecoveryEntityPort();
    usecase = SyncLocalReportsToLattice(source, entityPort);
  });

  test('returns empty when local list is empty', () async {
    final pushed = await usecase(const []);
    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
  });

  test('pushes locals that are missing on lattice', () async {
    source.knownIds = {'on-lattice'};
    final locals = [
      makeReport(entityId: 'on-lattice'),
      makeReport(entityId: 'missing-1'),
      makeReport(entityId: 'missing-2'),
    ];

    final pushed = await usecase(locals);

    expect(pushed, containsAll(['missing-1', 'missing-2']));
    expect(pushed, hasLength(2));
    expect(entityPort.recoveryUpserts.map((u) => u.entityId),
        containsAll(['missing-1', 'missing-2']));
  });

  test('does not push locals already present on lattice', () async {
    source.knownIds = {'a', 'b'};
    final locals = [
      makeReport(entityId: 'a'),
      makeReport(entityId: 'b'),
    ];

    final pushed = await usecase(locals);
    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
  });

  test('skips reports with null or empty entityId', () async {
    final locals = [
      makeReport(entityId: null),
      makeReport(entityId: ''),
    ];

    final pushed = await usecase(locals);
    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
  });

  test('skips reports that are not outgoing even if missing on lattice',
      () async {
    final locals = [
      makeReport(entityId: 'external-1', isOutgoing: false),
      makeReport(entityId: 'external-2', isOutgoing: false),
    ];

    final pushed = await usecase(locals);
    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
    expect(entityPort.navigatorUpserts, isEmpty);
  });

  test('does not resurrect tombstoned entities (id known but not live)',
      () async {
    source.knownIds = {'tombstoned'};
    final locals = [makeReport(entityId: 'tombstoned')];

    final pushed = await usecase(locals);
    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
  });

  test('uses publishNavigatorEntity when local report has navigator data',
      () async {
    final locals = [
      makeReport(
        entityId: 'with-nav',
        navigatorLatitude: 34.5,
        navigatorLongitude: -85.5,
      ),
    ];

    await usecase(locals);

    expect(entityPort.navigatorUpserts, hasLength(1));
    expect(entityPort.recoveryUpserts, isEmpty);
    expect(entityPort.navigatorUpserts.first.navigatorPosition,
        const LatLng(34.5, -85.5));
  });

  test('preserves routeGeometry when pushing with navigator data', () async {
    final geometry = [
      const LatLng(33.0, -84.0),
      const LatLng(33.5, -84.5),
    ];
    final locals = [
      makeReport(
        entityId: 'with-geo',
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
        routeGeometry: geometry,
      ),
    ];

    await usecase(locals);

    expect(entityPort.navigatorUpserts.first.routeGeometry, geometry);
  });

  test('uses publishRecoveryEntity when local report has no navigator data',
      () async {
    final locals = [makeReport(entityId: 'no-nav')];

    await usecase(locals);

    expect(entityPort.recoveryUpserts, hasLength(1));
    expect(entityPort.navigatorUpserts, isEmpty);
  });

  test('failed push is not in returned list but does not stop later pushes',
      () async {
    entityPort.publishOkByEntityId = {'fail': false, 'ok': true};
    final locals = [
      makeReport(entityId: 'fail'),
      makeReport(entityId: 'ok'),
    ];

    final pushed = await usecase(locals);

    expect(pushed, ['ok']);
    expect(entityPort.recoveryUpserts.map((u) => u.entityId),
        containsAll(['fail', 'ok']));
  });

  test('returns empty list when fetchKnownRecoveryEntityIds throws', () async {
    source.shouldThrow = true;
    final locals = [makeReport(entityId: 'x')];

    final pushed = await usecase(locals);

    expect(pushed, isEmpty);
    expect(entityPort.recoveryUpserts, isEmpty);
  });

  test('only fetches known ids once per invocation', () async {
    final locals = [
      makeReport(entityId: 'a'),
      makeReport(entityId: 'b'),
      makeReport(entityId: 'c'),
    ];

    await usecase(locals);

    expect(source.fetchKnownCallCount, 1);
  });

  test('passes vehicle position correctly when pushing without navigator',
      () async {
    final locals = [makeReport(entityId: 'x')];

    await usecase(locals);

    expect(entityPort.recoveryUpserts.first.position,
        const LatLng(33.0, -84.0));
    expect(entityPort.recoveryUpserts.first.typeName, 'Wrecker');
  });
}
