import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/reports/reportsDao.dart';
import 'package:recovery_ops/data/repositories/reportsRepoImpl.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';

void main() {
  late AppDatabase db;
  late ReportsDao dao;
  late ReportsRepoImpl repo;

  final ts1 = DateTime.utc(2026, 3, 24, 10, 0);
  final ts2 = DateTime.utc(2026, 3, 24, 11, 0);

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    dao = ReportsDao(db);
    repo = ReportsRepoImpl(dao);
  });

  tearDown(() async {
    await db.close();
  });

  RecoveryReport makeReport({
    String fromCallsign = 'Ghost',
    String bumperNumber = 'HQ-42',
    String issue = 'flat tire',
    String recoveryType = 'Wrecker',
    double latitude = 33.0,
    double longitude = -84.0,
    DateTime? timestamp,
    bool isOutgoing = false,
    bool isRead = false,
  }) {
    return RecoveryReport(
      fromCallsign: fromCallsign,
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? ts1,
      isOutgoing: isOutgoing,
      isRead: isRead,
    );
  }

  group('getAllReports', () {
    test('returns empty list when database is empty', () async {
      final reports = await repo.getAllReports();
      expect(reports, isEmpty);
    });

    test('returns domain entities with all fields mapped', () async {
      await repo.insertReport(makeReport());
      final reports = await repo.getAllReports();

      expect(reports.length, 1);
      final r = reports.first;
      expect(r, isA<RecoveryReport>());
      expect(r.id, isNotNull);
      expect(r.fromCallsign, 'Ghost');
      expect(r.bumperNumber, 'HQ-42');
      expect(r.issue, 'flat tire');
      expect(r.recoveryType, 'Wrecker');
      expect(r.latitude, 33.0);
      expect(r.longitude, -84.0);
      expect(r.isOutgoing, isFalse);
      expect(r.isRead, isFalse);
    });

    test('preserves ordering from DAO (timestamp desc)', () async {
      await repo.insertReport(makeReport(bumperNumber: 'A-01', timestamp: ts1));
      await repo.insertReport(makeReport(bumperNumber: 'B-02', timestamp: ts2));

      final reports = await repo.getAllReports();
      expect(reports[0].bumperNumber, 'B-02');
      expect(reports[1].bumperNumber, 'A-01');
    });
  });

  group('insertReport', () {
    test('persists report to database', () async {
      await repo.insertReport(makeReport(isOutgoing: true, isRead: true));

      final reports = await repo.getAllReports();
      expect(reports.length, 1);
      expect(reports.first.isOutgoing, isTrue);
      expect(reports.first.isRead, isTrue);
    });

    test('multiple inserts create separate rows', () async {
      await repo.insertReport(makeReport(bumperNumber: 'A'));
      await repo.insertReport(makeReport(bumperNumber: 'B'));
      await repo.insertReport(makeReport(bumperNumber: 'C'));

      final reports = await repo.getAllReports();
      expect(reports.length, 3);
    });
  });

  group('markAsRead', () {
    test('marks specific report as read by id', () async {
      await repo.insertReport(makeReport(bumperNumber: 'A', timestamp: ts1));
      await repo.insertReport(makeReport(bumperNumber: 'B', timestamp: ts2));

      final reports = await repo.getAllReports();
      final targetId = reports.last.id!;
      await repo.markAsRead(targetId);

      final after = await repo.getAllReports();
      expect(after.firstWhere((r) => r.id == targetId).isRead, isTrue);
      expect(after.firstWhere((r) => r.id != targetId).isRead, isFalse);
    });
  });

  group('markAllAsRead', () {
    test('marks all unread reports as read', () async {
      await repo.insertReport(makeReport(bumperNumber: 'A', timestamp: ts1));
      await repo.insertReport(makeReport(bumperNumber: 'B', timestamp: ts2));

      await repo.markAllAsRead();

      final after = await repo.getAllReports();
      expect(after.every((r) => r.isRead), isTrue);
    });

    test('is a no-op on empty database', () async {
      await repo.markAllAsRead();
      expect(await repo.getAllReports(), isEmpty);
    });
  });
}
