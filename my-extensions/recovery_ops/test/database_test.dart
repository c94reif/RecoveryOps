import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';

void main() {
  late AppDatabase db;
  late ProfileDao profileDao;
  late ReportsDao reportsDao;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    profileDao = ProfileDao(db);
    reportsDao = ReportsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileDao', () {
    test('getProfile returns null when database is empty', () async {
      final profile = await profileDao.getProfile();
      expect(profile, isNull);
    });

    test('saveProfile inserts a new profile', () async {
      await profileDao.saveProfile(
          name: 'John Doe', callSign: 'Ghost', unit: 'Alpha 1');

      final profile = await profileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'John Doe');
      expect(profile.callSign, 'Ghost');
      expect(profile.unit, 'Alpha 1');
    });

    test('saveProfile updates an existing profile', () async {
      await profileDao.saveProfile(
          name: 'John Doe', callSign: 'Ghost', unit: 'Alpha 1');
      await profileDao.saveProfile(
          name: 'Jane Doe', callSign: 'Wraith', unit: 'Bravo 2');

      final profile = await profileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Jane Doe');
      expect(profile.callSign, 'Wraith');
      expect(profile.unit, 'Bravo 2');
    });

    test('saveProfile upsert keeps only one row', () async {
      await profileDao.saveProfile(name: 'First', callSign: 'C1', unit: 'U1');
      await profileDao.saveProfile(name: 'Second', callSign: 'C2', unit: 'U2');
      await profileDao.saveProfile(name: 'Third', callSign: 'C3', unit: 'U3');

      final allRows = await db.select(db.profiles).get();
      expect(allRows.length, 1);
      expect(allRows.first.name, 'Third');
    });

    test('profile id is auto-incremented', () async {
      await profileDao.saveProfile(name: 'Test', callSign: 'T', unit: 'U');
      final profile = await profileDao.getProfile();
      expect(profile!.id, greaterThan(0));
    });

    test('handles unicode characters in profile fields', () async {
      await profileDao.saveProfile(
          name: 'Jöhn Dœ', callSign: '幽灵', unit: 'Álpha');
      final profile = await profileDao.getProfile();
      expect(profile!.name, 'Jöhn Dœ');
      expect(profile.callSign, '幽灵');
      expect(profile.unit, 'Álpha');
    });

    test('handles empty strings in profile fields', () async {
      await profileDao.saveProfile(name: '', callSign: '', unit: '');
      final profile = await profileDao.getProfile();
      expect(profile!.name, '');
      expect(profile.callSign, '');
      expect(profile.unit, '');
    });
  });

  group('ReportsDao', () {
    Future<void> insertSample({
      String bumperNumber = 'HQ-42',
      DateTime? timestamp,
      bool isRead = false,
      bool isOutgoing = false,
    }) async {
      await reportsDao.insertReport(
        fromCallsign: 'Ghost',
        bumperNumber: bumperNumber,
        issue: 'flat tire',
        recoveryType: 'Wrecker',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: timestamp ?? DateTime.utc(2026, 3, 24, 12, 0),
        isOutgoing: isOutgoing,
        isRead: isRead,
      );
    }

    test('getAllReports returns empty list on fresh database', () async {
      final reports = await reportsDao.getAllReports();
      expect(reports, isEmpty);
    });

    test('insertReport creates a new row', () async {
      await insertSample();
      final reports = await reportsDao.getAllReports();
      expect(reports.length, 1);
    });

    test('reports are ordered by timestamp descending', () async {
      await insertSample(
          bumperNumber: 'OLD', timestamp: DateTime.utc(2026, 1, 1));
      await insertSample(
          bumperNumber: 'NEW', timestamp: DateTime.utc(2026, 6, 1));
      await insertSample(
          bumperNumber: 'MID', timestamp: DateTime.utc(2026, 3, 1));

      final reports = await reportsDao.getAllReports();
      expect(reports[0].bumperNumber, 'NEW');
      expect(reports[1].bumperNumber, 'MID');
      expect(reports[2].bumperNumber, 'OLD');
    });

    test('markAsRead only affects target row', () async {
      await insertSample(
          bumperNumber: 'A', timestamp: DateTime.utc(2026, 1, 1));
      await insertSample(
          bumperNumber: 'B', timestamp: DateTime.utc(2026, 2, 1));

      final before = await reportsDao.getAllReports();
      await reportsDao.markAsRead(before.last.id);

      final after = await reportsDao.getAllReports();
      expect(after.firstWhere((r) => r.bumperNumber == 'A').isRead, isTrue);
      expect(after.firstWhere((r) => r.bumperNumber == 'B').isRead, isFalse);
    });

    test('markAllAsRead sets all rows to read', () async {
      await insertSample(
          bumperNumber: 'A', timestamp: DateTime.utc(2026, 1, 1));
      await insertSample(
          bumperNumber: 'B', timestamp: DateTime.utc(2026, 2, 1));

      await reportsDao.markAllAsRead();

      final after = await reportsDao.getAllReports();
      expect(after.every((r) => r.isRead), isTrue);
    });

    test('markAllAsRead does not affect already-read rows', () async {
      await insertSample(
          bumperNumber: 'A', isRead: true, timestamp: DateTime.utc(2026, 1, 1));
      await insertSample(
          bumperNumber: 'B',
          isRead: false,
          timestamp: DateTime.utc(2026, 2, 1));

      await reportsDao.markAllAsRead();

      final after = await reportsDao.getAllReports();
      expect(after.every((r) => r.isRead), isTrue);
    });
  });

  group('schema', () {
    test('both profiles and reports tables exist', () async {
      await db.select(db.profiles).get();
      await db.select(db.reports).get();
    });

    test('schemaVersion is 5', () {
      expect(db.schemaVersion, 5);
    });
  });
}
