import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';

void main() {
  late AppDatabase db;
  late ProfileDao profileDao;
  late SessionsDao sessionsDao;
  late CheckResultsDao resultsDao;
  late PmcsFaultsDao faultsDao;
  late PmcsReportsDao reportsDao;
  late QueuedSubmissionsDao queueDao;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    profileDao = ProfileDao(db);
    sessionsDao = SessionsDao(db);
    resultsDao = CheckResultsDao(db);
    faultsDao = PmcsFaultsDao(db);
    reportsDao = PmcsReportsDao(db);
    queueDao = QueuedSubmissionsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertSession({
    String sessionId = 'session-1',
    String bumperNumber = 'A-11',
    String status = 'IN_PROGRESS',
    String completedPhases = '',
    DateTime? startedAt,
  }) {
    return sessionsDao.insertSession(
      sessionId: sessionId,
      bumperNumber: bumperNumber,
      vehicleType: 'STRYKER',
      operator: 'SGT SMITH',
      uic: 'WJ8TAA',
      startedAt: startedAt ?? DateTime.utc(2026, 3, 24, 6),
      completedPhases: completedPhases,
      status: status,
      latitude: 33.0,
      longitude: -84.0,
    );
  }

  group('ProfileDao', () {
    test('getProfile returns null on a fresh database', () async {
      expect(await profileDao.getProfile(), isNull);
    });

    test('saveProfile inserts then updates the single row', () async {
      await profileDao.saveProfile(uic: 'WJ8TAA');
      await profileDao.saveProfile(uic: 'WAB4C0');

      final rows = await db.select(db.profiles).get();
      expect(rows, hasLength(1));
      expect(rows.single.uic, 'WAB4C0');
    });
  });

  group('SessionsDao', () {
    test('only in-progress sessions are open', () async {
      await insertSession(sessionId: 'open-1');
      await insertSession(sessionId: 'done-1', status: 'SUBMITTED');

      final open = await sessionsDao.getOpenSessions();
      expect(open.map((s) => s.sessionId), ['open-1']);
    });

    test('open sessions come back newest first', () async {
      await insertSession(
          sessionId: 'older', startedAt: DateTime.utc(2026, 3, 1));
      await insertSession(
          sessionId: 'newer', startedAt: DateTime.utc(2026, 3, 20));

      final open = await sessionsDao.getOpenSessions();
      expect(open.map((s) => s.sessionId), ['newer', 'older']);
    });

    test('getBySessionId finds the session', () async {
      await insertSession(sessionId: 'session-9');

      final found = await sessionsDao.getBySessionId('session-9');
      expect(found?.bumperNumber, 'A-11');
    });

    test('getBySessionId returns null for an unknown id', () async {
      expect(await sessionsDao.getBySessionId('nope'), isNull);
    });

    test('updateSession writes the completed phases and status', () async {
      await insertSession(sessionId: 'session-1');

      await sessionsDao.updateSession(
        sessionId: 'session-1',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        submittedAt: DateTime.utc(2026, 3, 24, 9),
        completedPhases: 'BEFORE,DURING',
        status: 'SUBMITTED',
        latitude: 33.0,
        longitude: -84.0,
      );

      final row = await sessionsDao.getBySessionId('session-1');
      expect(row?.completedPhases, 'BEFORE,DURING');
      expect(row?.status, 'SUBMITTED');
      expect(await sessionsDao.getOpenSessions(), isEmpty);
    });

    test('deleteBySessionId removes only that session', () async {
      await insertSession(sessionId: 'keep');
      await insertSession(sessionId: 'drop');

      await sessionsDao.deleteBySessionId('drop');

      final open = await sessionsDao.getOpenSessions();
      expect(open.map((s) => s.sessionId), ['keep']);
    });
  });

  group('CheckResultsDao', () {
    Future<void> answer(String itemId, int index,
        {String phase = 'BEFORE', String sessionId = 'session-1'}) {
      return resultsDao.upsertResult(
        sessionId: sessionId,
        phase: phase,
        itemId: itemId,
        faultIndex: index,
        faultLabel: 'label-$index',
        severity: index == 0 ? null : 'DASH',
        recordedAt: DateTime.utc(2026, 3, 24, 7),
      );
    }

    test('stores an answer', () async {
      await answer('B-ENG-01', 1);

      final rows = await resultsDao.getResults('session-1', 'BEFORE');
      expect(rows, hasLength(1));
      expect(rows.single.faultIndex, 1);
    });

    test('re-answering a check replaces it rather than duplicating', () async {
      await answer('B-ENG-01', 1);
      await answer('B-ENG-01', 0);

      final rows = await resultsDao.getResults('session-1', 'BEFORE');
      expect(rows, hasLength(1));
      expect(rows.single.faultIndex, 0);
      expect(rows.single.severity, isNull);
    });

    test('the same item in another phase is a separate answer', () async {
      await answer('SHARED-01', 1);
      await answer('SHARED-01', 2, phase: 'AFTER');

      expect(await resultsDao.getResults('session-1', 'BEFORE'), hasLength(1));
      expect(await resultsDao.getResults('session-1', 'AFTER'), hasLength(1));
    });

    test('the same item in another session is a separate answer', () async {
      await answer('B-ENG-01', 1);
      await answer('B-ENG-01', 2, sessionId: 'session-2');

      expect(await resultsDao.getResults('session-1', 'BEFORE'), hasLength(1));
      expect(await resultsDao.getResults('session-2', 'BEFORE'), hasLength(1));
    });

    test('deleteForSession clears every phase of that session', () async {
      await answer('B-ENG-01', 1);
      await answer('A-CDN-01', 1, phase: 'AFTER');
      await answer('B-ENG-01', 1, sessionId: 'session-2');

      await resultsDao.deleteForSession('session-1');

      expect(await resultsDao.getResults('session-1', 'BEFORE'), isEmpty);
      expect(await resultsDao.getResults('session-1', 'AFTER'), isEmpty);
      expect(await resultsDao.getResults('session-2', 'BEFORE'), hasLength(1));
    });
  });

  group('QueuedSubmissionsDao', () {
    Future<int> park({String transport = 'lattice', DateTime? createdAt}) {
      return queueDao.insertRow(
        entityId: 'entity-1',
        bumperNumber: 'A-11',
        vehicleType: 'Stryker',
        redXCount: 1,
        faultCount: 3,
        latitude: 33.0,
        longitude: -84.0,
        payload: '{"type":"ivy_pulse.report"}',
        transport: transport,
        createdAt: createdAt ?? DateTime.utc(2026, 3, 24, 9),
      );
    }

    test('parks a submission and counts it', () async {
      await park();
      expect(await queueDao.count(), 1);
    });

    test('drains oldest first', () async {
      await park(createdAt: DateTime.utc(2026, 3, 24, 10));
      await park(transport: 'mesh', createdAt: DateTime.utc(2026, 3, 24, 8));

      final rows = await queueDao.getAll();
      expect(rows.first.transport, 'mesh');
    });

    test('deleteById removes only that row', () async {
      final first = await park();
      await park(transport: 'mesh');

      await queueDao.deleteById(first);

      final rows = await queueDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.transport, 'mesh');
    });

    test('the payload survives a round trip verbatim', () async {
      await park();

      final rows = await queueDao.getAll();
      expect(rows.single.payload, '{"type":"ivy_pulse.report"}');
    });
  });

  group('schema', () {
    test('every table exists', () async {
      await db.select(db.profiles).get();
      await db.select(db.pmcsSessions).get();
      await db.select(db.checkResults).get();
      await db.select(db.pmcsFaults).get();
      await db.select(db.pmcsReports).get();
      await db.select(db.queuedSubmissions).get();
    });

    test('schemaVersion is 2 — the UIC-only profile and the signature columns',
        () {
      expect(db.schemaVersion, 2);
    });
  });

  group('PmcsFaultsDao and PmcsReportsDao', () {
    test('faults are stored and read back per session', () async {
      await faultsDao.replacePhaseFaults(
        'session-1',
        'BEFORE',
        [
          PmcsFaultsCompanion.insert(
            sessionId: 'session-1',
            itemId: 'B-BRK-01',
            phase: 'BEFORE',
            category: 'BRAKES',
            subcategory: 'Brake Fluid',
            description: 'Reservoir between MIN and MAX',
            condition: 'Empty',
            severity: 'RED_X',
            recordedAt: DateTime.utc(2026, 3, 24, 7),
          ),
        ],
      );

      final rows = await faultsDao.getForSession('session-1');
      expect(rows, hasLength(1));
      expect(rows.single.severity, 'RED_X');
    });

    test('reports come back newest first and mark read', () async {
      await reportsDao.insertReport(
        entityId: 'older',
        fromCallsign: 'Mesh',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        phases: 'BEFORE',
        faultsJson: '[]',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 3, 1),
        isOutgoing: false,
        isRead: false,
      );
      final newerId = await reportsDao.insertReport(
        entityId: 'newer',
        fromCallsign: 'Mesh',
        bumperNumber: 'A-12',
        vehicleType: 'JLTV',
        operator: 'SPC JONES',
        uic: 'WAB4C0',
        phases: 'BEFORE,AFTER',
        faultsJson: '[]',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 3, 20),
        isOutgoing: false,
        isRead: false,
      );

      final rows = await reportsDao.getAllReports();
      expect(rows.first.entityId, 'newer');

      await reportsDao.markAsRead(newerId);
      final after = await reportsDao.getAllReports();
      expect(after.firstWhere((r) => r.entityId == 'newer').isRead, isTrue);
      expect(after.firstWhere((r) => r.entityId == 'older').isRead, isFalse);

      await reportsDao.markAllAsRead();
      expect((await reportsDao.getAllReports()).every((r) => r.isRead), isTrue);
    });
  });
}
