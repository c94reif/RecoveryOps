import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/repositories/faults_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/reports_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/sessions_repo_impl.dart';
import 'package:ivy_pulse/data/services/drift_transaction_runner.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/location_repo.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';

import '../support/fakes.dart';

class DeferredLocation implements LocationRepository {
  final result = Completer<LatLng?>();
  @override
  Future<LatLng?> getCurrentLocation() => result.future;
}

void main() {
  late AppDatabase db;
  late SessionsRepoImpl sessions;
  late ReportsRepoImpl reports;
  late SubmitSession submit;
  final clock = FixedClock(DateTime.utc(2026, 9, 21));

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    sessions = SessionsRepoImpl(SessionsDao(db));
    reports = ReportsRepoImpl(PmcsReportsDao(db));
    submit = SubmitSession(
      sessionsRepository: sessions,
      reportsRepository: reports,
      faultsRepository: FaultsRepoImpl(PmcsFaultsDao(db)),
      buildSessionReport: BuildSessionReport(clock),
      clock: clock,
      transactionRunner: DriftTransactionRunner(db),
    );
  });
  tearDown(() => db.close());

  test('concurrent deliveries share one saved row and preserve read state',
      () async {
    final incoming = buildReport(
        isOutgoing: false,
        isRead: false,
        faults: [buildFault(note: 'Leak at left hose')]);
    final copies = await Future.wait(
        List.generate(12, (_) => reports.insertReport(incoming)));
    expect(copies.map((r) => r.id).toSet(), hasLength(1));
    await reports.markAsRead(copies.first.id!);
    final repeated = await reports.insertReport(incoming);
    expect(repeated.isRead, isTrue);
    expect(repeated.faults.single.note, 'Leak at left hose');
    expect(await reports.getAllReports(), hasLength(1));
  });

  test('an echoed delivery cannot replace a local signed report', () async {
    final original =
        await reports.insertReport(buildReport(signature: buildSignature()));
    final echo = await reports.insertReport(
        buildReport(isOutgoing: false, isRead: false, fromCallsign: 'relay'));
    expect(echo.id, original.id);
    expect(echo.isOutgoing, isTrue);
    expect(echo.isRead, isTrue);
    expect(echo.signature, isNotNull);
    expect(echo.fromCallsign, 'You');
  });

  test('a session update failure rolls back the report and allows a retry',
      () async {
    final session = await sessions.insert(buildSession());
    await db.customStatement("""
      CREATE TRIGGER fail_submission BEFORE UPDATE ON pmcs_sessions
      WHEN NEW.status = 'SUBMITTED'
      BEGIN SELECT RAISE(ABORT, 'simulated interrupted save'); END
    """);
    await expectLater(submit(session), throwsA(isA<Exception>()));
    expect(await reports.getAllReports(), isEmpty);
    expect((await sessions.getBySessionId(session.sessionId))!.status,
        SessionStatus.inProgress);
    await db.customStatement('DROP TRIGGER fail_submission');
    final saved = await submit(session);
    await submit(session);
    expect(await reports.getAllReports(), hasLength(1));
    expect(saved.entityId, session.sessionId);
    expect(await sessions.getOpenSessions(), isEmpty);
  });

  test('submitting a discarded inspection cannot leave an orphan report',
      () async {
    final session = await sessions.insert(buildSession());
    await sessions.deleteBySessionId(session.sessionId);
    await expectLater(submit(session), throwsStateError);
    expect(await reports.getAllReports(), isEmpty);
  });

  test('startup does not wait for GPS and a late fix preserves completed work',
      () async {
    final location = DeferredLocation();
    final start = StartSession(
        repository: sessions,
        locationRepository: location,
        clock: clock,
        idGenerator: FakeIdGenerator(['fast-start']));
    final session = await start(
        bumperNumber: 'a-11', vehicleType: VehicleType.stryker, uic: 'wj8taa');
    expect(location.result.isCompleted, isFalse);
    expect(session.latitude, isNull);
    final progressed = session.copyWith(completedPhases: [PmcsPhase.before]);
    await sessions.update(progressed);
    location.result.complete(const LatLng(38.25, -104.75));
    await Future<void>.delayed(Duration.zero);
    // A save from the screen's older snapshot must not erase the fix.
    await sessions.update(progressed);
    final stored = await sessions.getBySessionId(session.sessionId);
    expect(stored!.completedPhases, [PmcsPhase.before]);
    expect(stored.latitude, 38.25);
    final report = await submit(progressed);
    expect(report.latitude, 38.25);
    expect(report.longitude, -104.75);
  });

  test('late GPS cannot alter a submitted or discarded inspection', () async {
    final session =
        await sessions.insert(buildSession(latitude: null, longitude: null));
    await submit(session);
    await sessions.updateLocation(session.sessionId, 38, -104);
    expect(
        (await sessions.getBySessionId(session.sessionId))!.latitude, isNull);
    expect((await reports.getAllReports()).single.latitude, 0);
    await sessions.deleteBySessionId(session.sessionId);
    await sessions.updateLocation(session.sessionId, 38, -104);
    expect(await sessions.getBySessionId(session.sessionId), isNull);
  });

  test(
      'a v2 upgrade removes duplicates without losing the signed copy or notes',
      () async {
    final dir = Directory.systemTemp.createTempSync('ivy_report_v2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/reports.sqlite');
    final seed = AppDatabase.test(NativeDatabase(file));
    final seedReports = ReportsRepoImpl(PmcsReportsDao(seed));
    final original = await seedReports.insertReport(buildReport(
        isRead: false,
        signature: buildSignature(),
        faults: [buildFault(note: 'Hose leaking')]));
    await seed.close();
    // v2 has the same columns but no report identity index.
    final raw = sqlite3.open(file.path);
    raw.execute('DROP INDEX pmcs_reports_entity_id');
    raw.execute("""
      INSERT INTO pmcs_reports (entity_id, from_callsign, bumper_number,
        vehicle_type, operator, uic, phases, faults_json, latitude, longitude,
        timestamp, is_outgoing, is_read)
      SELECT entity_id, 'relay', bumper_number, vehicle_type, operator, uic,
        phases, '[]', latitude, longitude, timestamp + 1, 0, 1 FROM pmcs_reports
    """);
    raw.userVersion = 2;
    raw.close();
    final migrated = AppDatabase.test(NativeDatabase(file));
    addTearDown(migrated.close);
    final upgraded = ReportsRepoImpl(PmcsReportsDao(migrated));
    final rows = await upgraded.getAllReports();
    expect(rows, hasLength(1));
    expect(rows.single.id, original.id);
    expect(rows.single.isRead, isTrue);
    expect(rows.single.isOutgoing, isTrue);
    expect(rows.single.signature, isNotNull);
    expect(rows.single.faults.single.note, 'Hose leaking');
    await upgraded.insertReport(buildReport(isOutgoing: false));
    expect(await upgraded.getAllReports(), hasLength(1));
  });
}
