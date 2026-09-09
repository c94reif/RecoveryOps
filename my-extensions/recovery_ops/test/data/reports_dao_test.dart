import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';

void main() {
  late AppDatabase db;
  late ReportsDao dao;

  final ts1 = DateTime.utc(2026, 3, 24, 10, 0);
  final ts2 = DateTime.utc(2026, 3, 24, 11, 0);
  final ts3 = DateTime.utc(2026, 3, 24, 12, 0);

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    dao = ReportsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSample({
    String fromCallsign = 'Ghost',
    String bumperNumber = 'HQ-42',
    String issue = 'flat tire',
    String recoveryType = 'Wrecker',
    double latitude = 33.0,
    double longitude = -84.0,
    DateTime? timestamp,
    bool isOutgoing = false,
    bool isRead = false,
  }) async {
    await dao.insertReport(
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
      final reports = await dao.getAllReports();
      expect(reports, isEmpty);
    });

    test('returns inserted reports', () async {
      await insertSample();
      final reports = await dao.getAllReports();
      expect(reports.length, 1);
      expect(reports.first.bumperNumber, 'HQ-42');
      expect(reports.first.fromCallsign, 'Ghost');
      expect(reports.first.issue, 'flat tire');
      expect(reports.first.recoveryType, 'Wrecker');
      expect(reports.first.latitude, 33.0);
      expect(reports.first.longitude, -84.0);
    });

    test('returns reports ordered by timestamp descending', () async {
      await insertSample(bumperNumber: 'A-01', timestamp: ts1);
      await insertSample(bumperNumber: 'B-02', timestamp: ts3);
      await insertSample(bumperNumber: 'C-03', timestamp: ts2);

      final reports = await dao.getAllReports();
      expect(reports.length, 3);
      expect(reports[0].bumperNumber, 'B-02');
      expect(reports[1].bumperNumber, 'C-03');
      expect(reports[2].bumperNumber, 'A-01');
    });
  });

  group('insertReport', () {
    test('auto-increments id', () async {
      await insertSample(bumperNumber: 'A-01');
      await insertSample(bumperNumber: 'B-02');

      final reports = await dao.getAllReports();
      final ids = reports.map((r) => r.id).toSet();
      expect(ids.length, 2);
    });

    test('stores isOutgoing correctly', () async {
      await insertSample(isOutgoing: true);
      final reports = await dao.getAllReports();
      expect(reports.first.isOutgoing, isTrue);
    });

    test('stores isRead correctly', () async {
      await insertSample(isRead: true);
      final reports = await dao.getAllReports();
      expect(reports.first.isRead, isTrue);
    });

    test('defaults isOutgoing to false', () async {
      await insertSample();
      final reports = await dao.getAllReports();
      expect(reports.first.isOutgoing, isFalse);
    });

    test('defaults isRead to false', () async {
      await insertSample();
      final reports = await dao.getAllReports();
      expect(reports.first.isRead, isFalse);
    });

    test('stores latitude and longitude as doubles', () async {
      await insertSample(latitude: 33.12345, longitude: -84.98765);
      final reports = await dao.getAllReports();
      expect(reports.first.latitude, closeTo(33.12345, 0.0001));
      expect(reports.first.longitude, closeTo(-84.98765, 0.0001));
    });

    test('stores timestamp correctly', () async {
      await insertSample(timestamp: ts2);
      final reports = await dao.getAllReports();
      // Drift may strip timezone info; compare milliseconds
      expect(
        reports.first.timestamp.millisecondsSinceEpoch,
        ts2.millisecondsSinceEpoch,
      );
    });
  });

  group('markAsRead', () {
    test('marks a specific report as read', () async {
      await insertSample(bumperNumber: 'A-01', timestamp: ts1);
      await insertSample(bumperNumber: 'B-02', timestamp: ts2);

      final before = await dao.getAllReports();
      final targetId = before.last.id;
      await dao.markAsRead(targetId);

      final after = await dao.getAllReports();
      final target = after.firstWhere((r) => r.id == targetId);
      final other = after.firstWhere((r) => r.id != targetId);
      expect(target.isRead, isTrue);
      expect(other.isRead, isFalse);
    });

    test('is idempotent — marking already-read report is a no-op', () async {
      await insertSample(isRead: true);
      final reports = await dao.getAllReports();
      await dao.markAsRead(reports.first.id);

      final after = await dao.getAllReports();
      expect(after.first.isRead, isTrue);
    });

    test('does nothing for non-existent id', () async {
      await insertSample();
      await dao.markAsRead(99999);

      final after = await dao.getAllReports();
      expect(after.first.isRead, isFalse);
    });
  });

  group('markAllAsRead', () {
    test('marks all unread reports as read', () async {
      await insertSample(bumperNumber: 'A-01', timestamp: ts1);
      await insertSample(bumperNumber: 'B-02', timestamp: ts2);
      await insertSample(bumperNumber: 'C-03', timestamp: ts3, isRead: true);

      await dao.markAllAsRead();

      final after = await dao.getAllReports();
      expect(after.every((r) => r.isRead), isTrue);
    });

    test('is a no-op when all reports are already read', () async {
      await insertSample(isRead: true);
      await dao.markAllAsRead();

      final after = await dao.getAllReports();
      expect(after.first.isRead, isTrue);
    });

    test('is a no-op on empty database', () async {
      await dao.markAllAsRead();
      final after = await dao.getAllReports();
      expect(after, isEmpty);
    });
  });
}
