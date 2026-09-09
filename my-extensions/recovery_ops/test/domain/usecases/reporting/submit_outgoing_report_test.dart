import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/usecases/reporting/submit_outgoing_report.dart';

class FakeReportsRepository implements ReportsRepository {
  final List<RecoveryReport> inserted = [];

  @override
  Future<void> insertReport(RecoveryReport report) async {
    inserted.add(report);
  }

  @override
  Future<List<RecoveryReport>> getAllReports() async => [];
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

void main() {
  late FakeReportsRepository repo;
  late SubmitOutgoingReport usecase;

  setUp(() {
    repo = FakeReportsRepository();
    usecase = SubmitOutgoingReport(repo);
  });

  test('returns a report with the provided fields', () async {
    final result = await usecase.call(
      entityId: 'entity-1',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      recoveryType: 'Wrecker',
      latitude: 33.0,
      longitude: -84.0,
    );

    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, 'Wrecker');
    expect(result.latitude, 33.0);
    expect(result.longitude, -84.0);
    expect(result.entityId, 'entity-1');
  });

  test('sets fromCallsign to You', () async {
    final result = await usecase.call(
      entityId: '',
      bumperNumber: 'HQ-42',
      issue: 'flat',
      recoveryType: 'Wrecker',
      latitude: 0,
      longitude: 0,
    );
    expect(result.fromCallsign, 'You');
  });

  test('marks report as outgoing and read', () async {
    final result = await usecase.call(
      entityId: '',
      bumperNumber: 'HQ-42',
      issue: 'flat',
      recoveryType: 'Wrecker',
      latitude: 0,
      longitude: 0,
    );
    expect(result.isOutgoing, isTrue);
    expect(result.isRead, isTrue);
  });

  test('sets a UTC timestamp', () async {
    final before = DateTime.now().toUtc();
    final result = await usecase.call(
      entityId: '',
      bumperNumber: 'HQ-42',
      issue: 'flat',
      recoveryType: 'Wrecker',
      latitude: 0,
      longitude: 0,
    );
    final after = DateTime.now().toUtc();

    expect(result.timestamp.isUtc, isTrue);
    expect(
        result.timestamp.isAfter(before) || result.timestamp == before, isTrue);
    expect(
        result.timestamp.isBefore(after) || result.timestamp == after, isTrue);
  });

  test('persists the report to the repository', () async {
    await usecase.call(
      entityId: '',
      bumperNumber: 'HQ-42',
      issue: 'flat',
      recoveryType: 'Wrecker',
      latitude: 0,
      longitude: 0,
    );
    expect(repo.inserted.length, 1);
    expect(repo.inserted.first.bumperNumber, 'HQ-42');
  });
}
