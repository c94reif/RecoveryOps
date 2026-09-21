import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// The schema exactly as v1 shipped it: a profile carrying a name, a rank and
/// a free-text unit, and no signature anywhere.
const v1Schema = '''
CREATE TABLE profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  rank TEXT NOT NULL,
  unit TEXT NOT NULL
);
CREATE TABLE pmcs_sessions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL UNIQUE,
  bumper_number TEXT NOT NULL,
  vehicle_type TEXT NOT NULL,
  operator TEXT NOT NULL,
  unit TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  submitted_at INTEGER,
  completed_phases TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'IN_PROGRESS',
  latitude REAL,
  longitude REAL
);
CREATE TABLE check_results (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  phase TEXT NOT NULL,
  item_id TEXT NOT NULL,
  fault_index INTEGER NOT NULL,
  fault_label TEXT NOT NULL,
  severity TEXT,
  note TEXT,
  recorded_at INTEGER NOT NULL
);
CREATE TABLE pmcs_faults (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  phase TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  description TEXT NOT NULL,
  condition TEXT NOT NULL,
  severity TEXT NOT NULL,
  note TEXT,
  recorded_at INTEGER NOT NULL
);
CREATE TABLE pmcs_reports (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  entity_id TEXT NOT NULL,
  from_callsign TEXT NOT NULL,
  bumper_number TEXT NOT NULL,
  vehicle_type TEXT NOT NULL,
  operator TEXT NOT NULL,
  unit TEXT NOT NULL,
  phases TEXT NOT NULL,
  faults_json TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp INTEGER NOT NULL,
  is_outgoing INTEGER NOT NULL DEFAULT 0,
  is_read INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE queued_submissions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  entity_id TEXT NOT NULL,
  bumper_number TEXT NOT NULL,
  vehicle_type TEXT NOT NULL,
  red_x_count INTEGER NOT NULL,
  fault_count INTEGER NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  payload TEXT NOT NULL,
  transport TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
''';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ivy_pulse_migration');
    file = File('${dir.path}/ivy_pulse_db.sqlite');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Lays down a v1 database with a row in each table the migration touches.
  void seedV1() {
    final raw = sqlite3.open(file.path);
    raw.execute(v1Schema);
    raw.execute(
      "INSERT INTO profiles (name, rank, unit) VALUES ('SMITH', 'SGT', 'WJ8TAA')",
    );
    raw.execute('''
      INSERT INTO pmcs_sessions
        (session_id, bumper_number, vehicle_type, operator, unit, started_at,
         completed_phases, status)
      VALUES
        ('session-1', 'A-11', 'STRYKER', 'SGT SMITH', 'WJ8TAA', 1774335600,
         'BEFORE', 'IN_PROGRESS')
    ''');
    raw.execute('''
      INSERT INTO pmcs_reports
        (entity_id, from_callsign, bumper_number, vehicle_type, operator, unit,
         phases, faults_json, latitude, longitude, timestamp, is_outgoing,
         is_read)
      VALUES
        ('report-1', 'You', 'A-11', 'STRYKER', 'SGT SMITH', 'WJ8TAA',
         'BEFORE', '[]', 33.0, -84.0, 1774342800, 1, 1)
    ''');
    raw.userVersion = 1;
    raw.close();
  }

  Future<AppDatabase> openMigrated() async {
    final db = AppDatabase.test(NativeDatabase(file));
    // Drift runs the migration lazily, on the first statement.
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('a v1 database opens at v2', () async {
    seedV1();

    final db = await openMigrated();
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 2);
  });

  test('the unit the operator was signed for becomes their UIC', () async {
    // The value was already a UIC in practice; the column name catches up
    // without the operator having to retype it.
    seedV1();

    final db = await openMigrated();
    addTearDown(db.close);

    final profile = await ProfileDao(db).getProfile();
    expect(profile, isNotNull);
    expect(profile!.uic, 'WJ8TAA');
  });

  test('the name and rank columns are gone', () async {
    seedV1();

    final db = await openMigrated();
    addTearDown(db.close);

    final columns =
        await db.customSelect('PRAGMA table_info(profiles)').get();
    final names = columns.map((row) => row.data['name']).toList();

    expect(names, containsAll(<Object?>['id', 'uic']));
    expect(names, isNot(contains('name')));
    expect(names, isNot(contains('rank')));
  });

  test('an in-progress session survives, renamed and unsigned', () async {
    // A Soldier part-way through a walk-around when the build updates must
    // still be able to finish it.
    seedV1();

    final db = await openMigrated();
    addTearDown(db.close);

    final session = await SessionsDao(db).getBySessionId('session-1');
    expect(session, isNotNull);
    expect(session!.uic, 'WJ8TAA');
    expect(session.bumperNumber, 'A-11');
    expect(session.completedPhases, 'BEFORE');
    expect(session.signatureJson, isNull);
  });

  test('a report stored before verification survives and reads unsigned',
      () async {
    seedV1();

    final db = await openMigrated();
    addTearDown(db.close);

    final reports = await PmcsReportsDao(db).getAllReports();
    expect(reports, hasLength(1));
    expect(reports.single.uic, 'WJ8TAA');
    expect(reports.single.operator, 'SGT SMITH');
    expect(reports.single.signatureJson, isNull);
  });

  test('a fresh install creates v2 directly, with no migration to run',
      () async {
    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    await ProfileDao(db).saveProfile(uic: 'WAB4C0');

    expect((await ProfileDao(db).getProfile())!.uic, 'WAB4C0');
  });
}
