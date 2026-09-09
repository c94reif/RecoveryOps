import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_remote_reports.dart';

class FakeRemoteReportSource implements RemoteReportSource {
  List<RecoveryReport> remoteReports = const [];
  bool shouldThrow = false;
  int fetchRemoteCallCount = 0;

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async {
    fetchRemoteCallCount++;
    if (shouldThrow) throw Exception('lattice offline');
    return remoteReports;
  }

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async => const {};

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async => null;

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async => null;
}

class FakeReportsRepository implements ReportsRepository {
  final List<RecoveryReport> inserted = [];
  bool shouldThrowOnInsert = false;

  @override
  Future<void> insertReport(RecoveryReport report) async {
    if (shouldThrowOnInsert) throw Exception('db error');
    inserted.add(report);
  }

  @override
  Future<List<RecoveryReport>> getAllReports() async => const [];
  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {}
  @override
  Future<void> clearNavigatorLocation(int id) async {}
  @override
  Future<void> markAsRead(int id) async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {}
  @override
  Future<void> deleteReport(int id) async {}
}

RecoveryReport makeRemoteReport({
  required String entityId,
  String bumperNumber = 'HQ-42',
}) {
  return RecoveryReport(
    entityId: entityId,
    fromCallsign: 'Mesh',
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 4, 14, 12),
  );
}

RecoveryReport makeLocalReport({
  required String entityId,
  bool isOutgoing = false,
}) {
  return RecoveryReport(
    id: 1,
    entityId: entityId,
    fromCallsign: 'Alpha',
    bumperNumber: 'HQ-42',
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 4, 14, 12),
    isOutgoing: isOutgoing,
  );
}

void main() {
  late FakeRemoteReportSource source;
  late FakeReportsRepository repo;
  late SyncRemoteReports usecase;

  setUp(() {
    source = FakeRemoteReportSource();
    repo = FakeReportsRepository();
    usecase = SyncRemoteReports(source, repo);
  });

  test('returns empty list when lattice has no reports', () async {
    final result = await usecase(const []);
    expect(result, isEmpty);
    expect(repo.inserted, isEmpty);
  });

  test('inserts and returns all reports when local list is empty', () async {
    source.remoteReports = [
      makeRemoteReport(entityId: 'entity-1'),
      makeRemoteReport(entityId: 'entity-2'),
    ];

    final result = await usecase(const []);

    expect(result.length, 2);
    expect(repo.inserted.length, 2);
    expect(
        result.map((r) => r.entityId), containsAll(['entity-1', 'entity-2']));
  });

  test('skips reports already present by entityId', () async {
    source.remoteReports = [
      makeRemoteReport(entityId: 'entity-1'),
      makeRemoteReport(entityId: 'entity-2'),
    ];

    final result = await usecase([makeLocalReport(entityId: 'entity-1')]);

    expect(result.length, 1);
    expect(result.first.entityId, 'entity-2');
    expect(repo.inserted.length, 1);
  });

  test('skips reports whose id matches an outgoing local report', () async {
    source.remoteReports = [makeRemoteReport(entityId: 'entity-own')];

    final result = await usecase(
        [makeLocalReport(entityId: 'entity-own', isOutgoing: true)]);

    expect(result, isEmpty);
    expect(repo.inserted, isEmpty);
  });

  test('skips remote reports with null or empty entityId', () async {
    source.remoteReports = [
      RecoveryReport(
        entityId: null,
        fromCallsign: 'Mesh',
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        recoveryType: 'Wrecker',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 4, 14),
      ),
      RecoveryReport(
        entityId: '',
        fromCallsign: 'Mesh',
        bumperNumber: 'HQ-43',
        issue: 'flat tire',
        recoveryType: 'Wrecker',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 4, 14),
      ),
    ];

    final result = await usecase(const []);
    expect(result, isEmpty);
    expect(repo.inserted, isEmpty);
  });

  test('dedupes within a single remote batch', () async {
    source.remoteReports = [
      makeRemoteReport(entityId: 'entity-1'),
      makeRemoteReport(entityId: 'entity-1', bumperNumber: 'HQ-99'),
    ];

    final result = await usecase(const []);

    expect(result.length, 1);
    expect(repo.inserted.length, 1);
  });

  test('returns empty list and swallows errors when lattice throws', () async {
    source.shouldThrow = true;
    final result = await usecase(const []);
    expect(result, isEmpty);
    expect(repo.inserted, isEmpty);
  });

  test('calls source exactly once per invocation', () async {
    await usecase(const []);
    expect(source.fetchRemoteCallCount, 1);
  });
}
