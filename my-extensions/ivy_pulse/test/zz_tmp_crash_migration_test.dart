import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:sqlite3/sqlite3.dart';

import 'data/schema_migration_test.dart' show v1Schema;

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ivy_pulse_crash');
    file = File('${dir.path}/ivy_pulse_db.sqlite');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void seedV1() {
    final raw = sqlite3.open(file.path);
    raw.execute(v1Schema);
    raw.execute(
      "INSERT INTO profiles (name, rank, unit) VALUES ('SMITH','SGT','WJ8TAA')",
    );
    raw.execute('''
      INSERT INTO pmcs_sessions
        (session_id, bumper_number, vehicle_type, operator, unit, started_at,
         completed_phases, status)
      VALUES ('session-1','A-11','STRYKER','SGT SMITH','WJ8TAA',1774335600,
              'BEFORE','IN_PROGRESS')
    ''');
    raw.userVersion = 1;
    raw.close();
  }

  test('interrupted after step 1 (profiles rewritten) -> reopen', () async {
    seedV1();
    // Simulate: alterTable(profiles) committed, then the process died before
    // the session/report renames. user_version is still 1 (drift only bumps
    // it after the whole onUpgrade returns).
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE tmp_p (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                          uic TEXT NOT NULL);
      INSERT INTO tmp_p (id, uic) SELECT id, unit FROM profiles;
      DROP TABLE profiles;
      ALTER TABLE tmp_p RENAME TO profiles;
    ''');
    expect(raw.userVersion, 1);
    raw.close();

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(() async {
      try {
        await db.close();
      } catch (_) {}
    });
    Object? err;
    try {
      await db.customSelect('SELECT 1').get();
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('REOPEN RESULT: $err');
    expect(err, isNotNull, reason: 'expected the re-run migration to blow up');
  });

  test('interrupted after the sessions rename -> reopen', () async {
    seedV1();
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE tmp_p (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                          uic TEXT NOT NULL);
      INSERT INTO tmp_p (id, uic) SELECT id, unit FROM profiles;
      DROP TABLE profiles;
      ALTER TABLE tmp_p RENAME TO profiles;
      ALTER TABLE pmcs_sessions RENAME COLUMN unit TO uic;
    ''');
    raw.close();

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(() async {
      try {
        await db.close();
      } catch (_) {}
    });
    Object? err;
    try {
      await db.customSelect('SELECT 1').get();
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('REOPEN RESULT 2: $err');
    expect(err, isNotNull);
  });
}
