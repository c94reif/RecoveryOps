import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/profile/profile_dao.dart';
import 'package:ivy_pulse/data/dao/queue/queued_submissions_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/repositories/faults_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/profile_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/queued_submissions_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/reports_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/results_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/sessions_repo_impl.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late SessionsDao sessionsDao;
  late CheckResultsDao resultsDao;
  late PmcsFaultsDao faultsDao;
  late PmcsReportsDao reportsDao;
  late QueuedSubmissionsDao queueDao;
  late ProfileDao profileDao;

  late SessionsRepoImpl sessions;
  late ResultsRepoImpl results;
  late FaultsRepoImpl faults;
  late ReportsRepoImpl reports;
  late QueuedSubmissionsRepoImpl queue;
  late ProfileRepoImpl profiles;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    sessionsDao = SessionsDao(db);
    resultsDao = CheckResultsDao(db);
    faultsDao = PmcsFaultsDao(db);
    reportsDao = PmcsReportsDao(db);
    queueDao = QueuedSubmissionsDao(db);
    profileDao = ProfileDao(db);

    sessions = SessionsRepoImpl(sessionsDao);
    results = ResultsRepoImpl(resultsDao);
    faults = FaultsRepoImpl(faultsDao);
    reports = ReportsRepoImpl(reportsDao);
    queue = QueuedSubmissionsRepoImpl(queueDao);
    profiles = ProfileRepoImpl(profileDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('SessionsRepoImpl', () {
    test('a session round-trips with its completed phases and coordinates',
        () async {
      final stored = await sessions.insert(buildSession(
        sessionId: 'session-7',
        bumperNumber: 'A-11',
        vehicleType: VehicleType.jltv,
        completedPhases: const [PmcsPhase.before, PmcsPhase.during],
        latitude: 33.25,
        longitude: -84.75,
      ));

      expect(stored.id, isNotNull);

      final read = await sessions.getBySessionId('session-7');
      expect(read!.id, stored.id);
      expect(read.bumperNumber, 'A-11');
      expect(read.vehicleType, VehicleType.jltv);
      // Nobody is stamped on a session until it is signed off.
      expect(read.operator, '');
      expect(read.uic, 'WJ8TAA');
      expect(read.signature, isNull);
      expect(read.completedPhases, [PmcsPhase.before, PmcsPhase.during]);
      expect(read.latitude, 33.25);
      expect(read.longitude, -84.75);
      expect(read.startedAt.toUtc(), DateTime.utc(2026, 3, 24, 6));
      expect(read.status, SessionStatus.inProgress);
    });

    test('a session started with no GPS fix reads back without coordinates',
        () async {
      await sessions.insert(buildSession(
        sessionId: 'no-fix',
        latitude: null,
        longitude: null,
      ));

      final read = await sessions.getBySessionId('no-fix');
      expect(read!.latitude, isNull);
      expect(read.longitude, isNull);
    });

    test(
        'a stored session naming a platform this build does not know is '
        'skipped rather than throwing, and does not take the operator other '
        'open sessions with it', () async {
      await sessions.insert(buildSession(sessionId: 'walkable'));
      await sessionsDao.insertSession(
        sessionId: 'abrams',
        bumperNumber: 'C-31',
        vehicleType: 'M1A2',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        startedAt: DateTime.utc(2026, 3, 25, 6),
        completedPhases: '',
        status: 'IN_PROGRESS',
      );

      expect(await sessionsDao.getOpenSessions(), hasLength(2),
          reason: 'both rows are on disk; only the readable one is offered');
      final open = await sessions.getOpenSessions();
      expect(open.map((s) => s.sessionId), ['walkable']);
    });

    test('a session for an unknown platform is not offered for resume',
        () async {
      await sessionsDao.insertSession(
        sessionId: 'abrams',
        bumperNumber: 'C-31',
        vehicleType: 'M1A2',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        startedAt: DateTime.utc(2026, 3, 25, 6),
        completedPhases: '',
        status: 'IN_PROGRESS',
      );

      expect(await sessions.getBySessionId('abrams'), isNull);
    });

    test('an unreadable status reads as still in progress', () async {
      await sessionsDao.insertSession(
        sessionId: 'odd-status',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        startedAt: DateTime.utc(2026, 3, 24, 6),
        completedPhases: '',
        status: 'ARCHIVED',
      );

      final read = await sessions.getBySessionId('odd-status');
      expect(read!.status, SessionStatus.inProgress);
    });

    test('a phase name this build does not know is dropped, not thrown on',
        () async {
      await sessionsDao.insertSession(
        sessionId: 'newer-build',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        startedAt: DateTime.utc(2026, 3, 24, 6),
        completedPhases: 'BEFORE,MIDNIGHT',
        status: 'IN_PROGRESS',
      );

      final read = await sessions.getBySessionId('newer-build');
      expect(read!.completedPhases, [PmcsPhase.before]);
    });

    test('submitting a session closes it out of the open list', () async {
      await sessions.insert(buildSession(sessionId: 'session-8'));

      await sessions.update(buildSession(
        sessionId: 'session-8',
        completedPhases: PmcsPhase.values,
        status: SessionStatus.submitted,
      ).copyWith(submittedAt: DateTime.utc(2026, 3, 24, 9)));

      expect(await sessions.getOpenSessions(), isEmpty);
      final read = await sessions.getBySessionId('session-8');
      expect(read!.status, SessionStatus.submitted);
      expect(read.completedPhases, PmcsPhase.values);
      expect(read.submittedAt!.toUtc(), DateTime.utc(2026, 3, 24, 9));
    });

    test('abandoning one session leaves the others alone', () async {
      await sessions.insert(buildSession(sessionId: 'keep'));
      await sessions.insert(buildSession(sessionId: 'drop'));

      await sessions.deleteBySessionId('drop');

      final open = await sessions.getOpenSessions();
      expect(open.map((s) => s.sessionId), ['keep']);
    });
  });

  group('ResultsRepoImpl', () {
    CheckResult answer({
      String itemId = 'B-ENG-01',
      int faultIndex = 2,
      FaultSeverity? severity = FaultSeverity.circleX,
      String? note,
    }) {
      return CheckResult(
        itemId: itemId,
        faultIndex: faultIndex,
        faultLabel: 'Low-Add Oil',
        severity: severity,
        note: note,
        recordedAt: DateTime.utc(2026, 3, 24, 7),
      );
    }

    test('an answer round-trips keyed by item id', () async {
      await results.upsertResult(
          'session-1', PmcsPhase.before, answer(note: 'quart low'));

      final stored = await results.getResults('session-1', PmcsPhase.before);
      expect(stored.keys, ['B-ENG-01']);
      expect(stored['B-ENG-01']!.faultIndex, 2);
      expect(stored['B-ENG-01']!.severity, FaultSeverity.circleX);
      expect(stored['B-ENG-01']!.note, 'quart low');
      expect(
          stored['B-ENG-01']!.recordedAt.toUtc(), DateTime.utc(2026, 3, 24, 7));
    });

    test('re-answering a check replaces it and clears the old severity',
        () async {
      await results.upsertResult('session-1', PmcsPhase.before, answer());
      await results.upsertResult(
        'session-1',
        PmcsPhase.before,
        answer(faultIndex: 0, severity: null),
      );

      final stored = await results.getResults('session-1', PmcsPhase.before);
      expect(stored, hasLength(1));
      expect(stored['B-ENG-01']!.isServiceable, isTrue);
      expect(stored['B-ENG-01']!.severity, isNull);
    });

    test('answers are scoped to their phase', () async {
      await results.upsertResult('session-1', PmcsPhase.before, answer());
      await results.upsertResult('session-1', PmcsPhase.after,
          answer(itemId: 'A-CDN-01', severity: FaultSeverity.dash));

      final before = await results.getResults('session-1', PmcsPhase.before);
      final after = await results.getResults('session-1', PmcsPhase.after);
      expect(before.keys, ['B-ENG-01']);
      expect(after.keys, ['A-CDN-01']);
    });

    test('deleteForSession clears every phase of that session only', () async {
      await results.upsertResult('session-1', PmcsPhase.before, answer());
      await results.upsertResult('session-1', PmcsPhase.after, answer());
      await results.upsertResult('session-2', PmcsPhase.before, answer());

      await results.deleteForSession('session-1');

      expect(await results.getResults('session-1', PmcsPhase.before), isEmpty);
      expect(await results.getResults('session-1', PmcsPhase.after), isEmpty);
      expect(await results.getResults('session-2', PmcsPhase.before),
          hasLength(1));
    });
  });

  group('FaultsRepoImpl', () {
    test('faults round-trip with their severity and operator note', () async {
      await faults.replacePhaseFaults(
        'session-1',
        [
          buildFault(severity: FaultSeverity.redX, note: 'reservoir empty'),
        ],
        phaseWireName: 'BEFORE',
      );

      final stored = await faults.getForSession('session-1');
      expect(stored, hasLength(1));
      expect(stored.single.itemId, 'B-ENG-01');
      expect(stored.single.phase, PmcsPhase.before);
      expect(stored.single.category, 'ENGINE COMPARTMENT');
      expect(stored.single.subcategory, 'Engine Oil Level');
      expect(stored.single.condition, 'Low-Add Oil');
      expect(stored.single.severity, FaultSeverity.redX);
      expect(stored.single.note, 'reservoir empty');
      expect(stored.single.recordedAt.toUtc(), DateTime.utc(2026, 3, 24, 7));
    });

    test('re-walking a phase after a correction replaces only that phase',
        () async {
      await faults.replacePhaseFaults(
        'session-1',
        [buildFault(severity: FaultSeverity.redX)],
        phaseWireName: 'BEFORE',
      );
      await faults.replacePhaseFaults(
        'session-1',
        [buildFault(phase: PmcsPhase.after, itemId: 'A-CDN-01')],
        phaseWireName: 'AFTER',
      );

      await faults.replacePhaseFaults('session-1', const [],
          phaseWireName: 'BEFORE');

      final stored = await faults.getForSession('session-1');
      expect(stored.map((f) => f.itemId), ['A-CDN-01']);
    });

    test('deleteForSession clears one session and not another', () async {
      await faults.replacePhaseFaults('session-1', [buildFault()],
          phaseWireName: 'BEFORE');
      await faults.replacePhaseFaults(
          'session-2', [buildFault(sessionId: 'session-2')],
          phaseWireName: 'BEFORE');

      await faults.deleteForSession('session-1');

      expect(await faults.getForSession('session-1'), isEmpty);
      expect(await faults.getForSession('session-2'), hasLength(1));
    });
  });

  group('ReportsRepoImpl', () {
    test('a report round-trips with its faults, severities and notes intact',
        () async {
      final stored = await reports.insertReport(buildReport(
        entityId: 'report-1',
        vehicleType: VehicleType.jltv,
        signature: buildSignature(),
        faults: [
          buildFault(severity: FaultSeverity.redX, note: 'brake fluid empty'),
          buildFault(itemId: 'B-TIR-02', severity: FaultSeverity.dash),
        ],
      ));

      expect(stored.id, isNotNull);

      final read = (await reports.getAllReports()).single;
      expect(read.id, stored.id);
      expect(read.entityId, 'report-1');
      expect(read.bumperNumber, 'A-11');
      expect(read.vehicleType, VehicleType.jltv);
      expect(read.operator, 'SGT SMITH');
      expect(read.uic, 'WJ8TAA');
      expect(read.phases, [PmcsPhase.before]);
      expect(read.latitude, 33.0);
      expect(read.longitude, -84.0);
      expect(read.timestamp.toUtc(), DateTime.utc(2026, 3, 24, 8));
      expect(read.faults.map((f) => f.severity),
          [FaultSeverity.redX, FaultSeverity.dash]);
      expect(read.faults.first.note, 'brake fluid empty');
      expect(read.faults.last.itemId, 'B-TIR-02');
      expect(read.isDeadlined, isTrue);
      expect(read.statusLabel, 'NMC');
      expect(read.isSignatureVerified, isTrue);
      expect(read.signature!.identity!.edipi, '1087987498');
      expect(read.signature!.identity!.displayName, 'SGT SMITH, JOHN A');
    });

    test('an unverified signature round-trips as unverified, with its reason',
        () async {
      await reports.insertReport(buildReport(
        entityId: 'report-unsigned',
        signature: buildUnverifiedSignature(
          blockedBy: CacRejection.noCamera,
        ),
      ));

      final read = (await reports.getAllReports()).single;

      expect(read.isSignatureVerified, isFalse);
      expect(read.signature!.blockedBy, CacRejection.noCamera);
      expect(read.signature!.identity, isNull);
    });

    test('a report stored before CAC verification reads as unverified',
        () async {
      // The one promotion that must never happen: no signature on disk is not
      // a signature the app can stand behind.
      await reports.insertReport(buildReport(entityId: 'legacy'));

      final read = (await reports.getAllReports()).single;

      expect(read.signature, isNull);
      expect(read.isSignatureVerified, isFalse);
    });

    test('stored faults are re-keyed to the entity id, not a local session',
        () async {
      await reports.insertReport(buildReport(
        entityId: 'report-2',
        faults: [buildFault(sessionId: 'senders-session')],
      ));

      final read = (await reports.getAllReports()).single;
      expect(read.faults.single.sessionId, 'report-2');
    });

    test(
        'a stored report naming a platform this build does not know is skipped '
        'rather than throwing, and does not take the rest of the list with it',
        () async {
      await reports.insertReport(buildReport(entityId: 'readable'));
      await reportsDao.insertReport(
        entityId: 'abrams',
        fromCallsign: 'Mesh',
        bumperNumber: 'C-31',
        vehicleType: 'M1A2',
        operator: 'SGT JONES',
        uic: 'WAB4C0',
        phases: 'BEFORE',
        faultsJson: '[]',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 3, 25, 8),
        isOutgoing: false,
        isRead: false,
      );

      expect(await reportsDao.getAllReports(), hasLength(2),
          reason: 'both rows are on disk; only the readable one is returned');
      final all = await reports.getAllReports();
      expect(all.map((r) => r.entityId), ['readable']);
    });

    test('a malformed fault blob costs the fault detail, never the report',
        () async {
      await reportsDao.insertReport(
        entityId: 'garbled',
        fromCallsign: 'Mesh',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        phases: 'BEFORE',
        faultsJson: 'not json',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 3, 24, 8),
        isOutgoing: false,
        isRead: false,
      );

      final read = (await reports.getAllReports()).single;
      expect(read.entityId, 'garbled');
      expect(read.faults, isEmpty);
    });

    test('an unknown phase name is dropped from a stored report', () async {
      await reportsDao.insertReport(
        entityId: 'newer-build',
        fromCallsign: 'Mesh',
        bumperNumber: 'A-11',
        vehicleType: 'STRYKER',
        operator: 'SGT SMITH',
        uic: 'WJ8TAA',
        phases: 'BEFORE,MIDNIGHT',
        faultsJson: '[]',
        latitude: 33.0,
        longitude: -84.0,
        timestamp: DateTime.utc(2026, 3, 24, 8),
        isOutgoing: false,
        isRead: false,
      );

      final read = (await reports.getAllReports()).single;
      expect(read.phases, [PmcsPhase.before]);
    });

    test('marking one report read leaves the others unread', () async {
      final first = await reports
          .insertReport(buildReport(entityId: 'first', isRead: false));
      await reports
          .insertReport(buildReport(entityId: 'second', isRead: false));

      await reports.markAsRead(first.id!);

      final all = await reports.getAllReports();
      expect(all.firstWhere((r) => r.entityId == 'first').isRead, isTrue);
      expect(all.firstWhere((r) => r.entityId == 'second').isRead, isFalse);
    });

    test('markAllAsRead clears the whole unread badge', () async {
      await reports.insertReport(buildReport(entityId: 'a', isRead: false));
      await reports.insertReport(buildReport(entityId: 'b', isRead: false));

      await reports.markAllAsRead();

      expect((await reports.getAllReports()).every((r) => r.isRead), isTrue);
    });

    test('deleting a report removes only that row', () async {
      final keep = await reports.insertReport(buildReport(entityId: 'keep'));
      final drop = await reports.insertReport(buildReport(entityId: 'drop'));

      await reports.deleteReport(drop.id!);

      final all = await reports.getAllReports();
      expect(all.map((r) => r.id), [keep.id]);
    });
  });

  group('QueuedSubmissionsRepoImpl', () {
    QueuedSubmission parked({
      String entityId = 'entity-1',
      String payload = '{"type":"ivy_pulse.report","entityId":"entity-1"}',
      TransportKind transport = TransportKind.lattice,
      DateTime? createdAt,
    }) {
      return QueuedSubmission(
        entityId: entityId,
        bumperNumber: 'A-11',
        vehicleType: 'Stryker',
        redXCount: 1,
        faultCount: 3,
        latitude: 33.0,
        longitude: -84.0,
        payload: payload,
        transport: transport,
        createdAt: createdAt ?? DateTime.utc(2026, 3, 24, 9),
      );
    }

    test('a parked submission round-trips with its payload verbatim', () async {
      final stored = await queue.insert(parked());

      expect(stored.id, isNotNull);

      final read = (await queue.getAll()).single;
      expect(read.id, stored.id);
      expect(read.entityId, 'entity-1');
      expect(read.bumperNumber, 'A-11');
      expect(read.vehicleType, 'Stryker');
      expect(read.redXCount, 1);
      expect(read.faultCount, 3);
      expect(read.latitude, 33.0);
      expect(read.longitude, -84.0);
      expect(read.payload, '{"type":"ivy_pulse.report","entityId":"entity-1"}');
      expect(read.transport, TransportKind.lattice);
      expect(read.createdAt.toUtc(), DateTime.utc(2026, 3, 24, 9));
    });

    test('each transport leg is parked as its own row', () async {
      await queue.insert(parked(transport: TransportKind.lattice));
      await queue.insert(parked(transport: TransportKind.mesh));

      final all = await queue.getAll();
      expect(all.map((s) => s.transport),
          [TransportKind.lattice, TransportKind.mesh]);
      expect(await queue.count(), 2);
    });

    test('the queue drains oldest first', () async {
      await queue.insert(
          parked(entityId: 'newer', createdAt: DateTime.utc(2026, 3, 24, 10)));
      await queue.insert(
          parked(entityId: 'older', createdAt: DateTime.utc(2026, 3, 24, 8)));

      final all = await queue.getAll();
      expect(all.map((s) => s.entityId), ['older', 'newer']);
    });

    test('the id handed back is the one that clears the row', () async {
      final stored = await queue.insert(parked());
      await queue.insert(parked(entityId: 'entity-2'));

      await queue.deleteById(stored.id!);

      final all = await queue.getAll();
      expect(all.map((s) => s.entityId), ['entity-2']);
      expect(await queue.count(), 1);
    });

    test('an empty queue counts zero', () async {
      expect(await queue.count(), 0);
      expect(await queue.getAll(), isEmpty);
    });
  });

  group('ProfileRepoImpl', () {
    test('there is no profile until the operator saves one', () async {
      expect(await profiles.getProfile(), isNull);
    });

    test('a profile round-trips', () async {
      await profiles.saveProfile(const Profile(uic: 'WJ8TAA'));

      final read = await profiles.getProfile();
      expect(read!.uic, 'WJ8TAA');
    });

    test('saving again edits the profile rather than adding a second',
        () async {
      await profiles.saveProfile(const Profile(uic: 'WJ8TAA'));
      await profiles.saveProfile(const Profile(uic: 'WAB4C0'));

      expect((await profiles.getProfile())!.uic, 'WAB4C0');
      expect(await db.select(db.profiles).get(), hasLength(1));
    });
  });
}
