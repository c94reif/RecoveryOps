import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/navigation/poll_route_geometry.dart';

class FakeRemoteReportSource implements RemoteReportSource {
  final Map<String, List<LatLng>?> geometryByEntityId = {};

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async {
    return geometryByEntityId[entityId];
  }

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async => const [];

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async => const {};

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async => null;
}

class FakeReportsRepository implements ReportsRepository {
  final List<MapEntry<int, String>> geometryUpdates = [];

  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {
    geometryUpdates.add(MapEntry(id, geometryJson));
  }

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
  Future<void> deleteReport(int id) async {}
}

RecoveryReport makeReport({
  int? id,
  String entityId = 'entity-1',
  List<LatLng>? routeGeometry,
}) {
  return RecoveryReport(
    id: id,
    entityId: entityId,
    fromCallsign: 'Alpha',
    bumperNumber: 'HQ-42',
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
    routeGeometry: routeGeometry,
  );
}

void main() {
  late FakeRemoteReportSource source;
  late FakeReportsRepository repo;
  late PollRouteGeometry usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    repo = FakeReportsRepository();
    usecase = PollRouteGeometry(source, repo);
  });

  test('returns updates for reports that receive geometry', () async {
    final geometry = [const LatLng(33.0, -84.0), const LatLng(34.0, -85.0)];
    source.geometryByEntityId['entity-1'] = geometry;

    final reports = [makeReport(id: 1, entityId: 'entity-1')];
    final updates = await usecase.call(reports);

    expect(updates.length, 1);
    expect(updates.first.index, 0);
    expect(updates.first.updatedReport.hasGeometry, isTrue);
    expect(updates.first.updatedReport.routeGeometry!.length, 2);
  });

  test('skips reports that already have geometry', () async {
    source.geometryByEntityId['entity-1'] = [const LatLng(33.0, -84.0)];

    final reports = [
      makeReport(
        id: 1,
        entityId: 'entity-1',
        routeGeometry: [const LatLng(33.0, -84.0)],
      ),
    ];
    final updates = await usecase.call(reports);
    expect(updates, isEmpty);
  });

  test('skips reports with null entityId', () async {
    final reportNoEntity = RecoveryReport(
      id: 1,
      entityId: null,
      fromCallsign: 'Alpha',
      bumperNumber: 'HQ-42',
      issue: 'flat',
      recoveryType: 'Wrecker',
      latitude: 33.0,
      longitude: -84.0,
      timestamp: DateTime.utc(2026, 3, 24, 12, 0),
    );
    final updates = await usecase.call([reportNoEntity]);
    expect(updates, isEmpty);
  });

  test('skips reports with empty entityId', () async {
    final reports = [makeReport(id: 1, entityId: '')];
    final updates = await usecase.call(reports);
    expect(updates, isEmpty);
  });

  test('does not update when fetched geometry is null', () async {
    source.geometryByEntityId['entity-1'] = null;

    final reports = [makeReport(id: 1, entityId: 'entity-1')];
    final updates = await usecase.call(reports);
    expect(updates, isEmpty);
  });

  test('does not update when fetched geometry is empty', () async {
    source.geometryByEntityId['entity-1'] = [];

    final reports = [makeReport(id: 1, entityId: 'entity-1')];
    final updates = await usecase.call(reports);
    expect(updates, isEmpty);
  });

  test('persists geometry to repository when report has an id', () async {
    final geometry = [const LatLng(33.0, -84.0), const LatLng(34.0, -85.0)];
    source.geometryByEntityId['entity-1'] = geometry;

    final reports = [makeReport(id: 5, entityId: 'entity-1')];
    await usecase.call(reports);

    expect(repo.geometryUpdates.length, 1);
    expect(repo.geometryUpdates.first.key, 5);
  });

  test('does not persist geometry when report has no id', () async {
    final geometry = [const LatLng(33.0, -84.0)];
    source.geometryByEntityId['entity-1'] = geometry;

    final reports = [makeReport(id: null, entityId: 'entity-1')];
    await usecase.call(reports);

    expect(repo.geometryUpdates, isEmpty);
  });

  test('handles multiple reports and returns correct indices', () async {
    source.geometryByEntityId['e-1'] = [const LatLng(1, 1)];
    source.geometryByEntityId['e-3'] = [const LatLng(3, 3)];

    final reports = [
      makeReport(id: 1, entityId: 'e-1'),
      makeReport(
        id: 2,
        entityId: 'e-2',
        routeGeometry: [const LatLng(2, 2)],
      ),
      makeReport(id: 3, entityId: 'e-3'),
    ];
    final updates = await usecase.call(reports);

    expect(updates.length, 2);
    expect(updates[0].index, 0);
    expect(updates[1].index, 2);
  });
}
