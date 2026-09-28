import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeSessionsRepository sessions;
  late FakeFaultsRepository faults;
  late FakeReportsRepository reports;
  late SubmitSession usecase;

  final clock = FixedClock(DateTime.utc(2026, 3, 24, 9));

  setUp(() {
    sessions = FakeSessionsRepository();
    faults = FakeFaultsRepository();
    reports = FakeReportsRepository();
    usecase = SubmitSession(
      transactionRunner: FakeTransactionRunner(),
      sessionsRepository: sessions,
      faultsRepository: faults,
      reportsRepository: reports,
      buildSessionReport: BuildSessionReport(clock),
      clock: clock,
    );
  });

  test('stores the report locally before anything touches the net', () async {
    await usecase(buildSession());

    expect(reports.reports, hasLength(1));
  });

  test('returns the stored report with its row id', () async {
    final report = await usecase(buildSession());

    expect(report.id, isNotNull);
  });

  test('carries the session faults onto the report', () async {
    await faults.replacePhaseFaults(
      'session-1',
      [
        buildFault(itemId: 'B-BRK-01', severity: FaultSeverity.redX),
        buildFault(itemId: 'B-ENG-01', severity: FaultSeverity.dash),
      ],
      phaseWireName: PmcsPhase.before.wireName,
    );

    final report = await usecase(buildSession());

    expect(report.faults, hasLength(2));
    expect(report.tally.redX, 1);
    expect(report.isDeadlined, isTrue);
  });

  test('marks the session submitted', () async {
    await usecase(buildSession());

    expect(sessions.updated.single.status, SessionStatus.submitted);
    expect(sessions.updated.single.submittedAt, DateTime.utc(2026, 3, 24, 9));
  });

  test('the report is outgoing and already read', () async {
    final report = await usecase(buildSession());

    expect(report.isOutgoing, isTrue);
    expect(report.isRead, isTrue);
    expect(report.fromCallsign, 'You');
  });

  test('the entity id is the session id, so both transports agree', () async {
    final report = await usecase(buildSession(sessionId: 'session-xyz'));

    expect(report.entityId, 'session-xyz');
  });

  test('a clean PMCS still submits, as fully mission capable', () async {
    final report = await usecase(buildSession());

    expect(report.faults, isEmpty);
    expect(report.isDeadlined, isFalse);
    expect(report.statusLabel, 'FMC');
  });

  test('a session with no GPS fix reports zeroed coordinates', () async {
    final report = await usecase(
      buildSession(latitude: null, longitude: null),
    );

    expect(report.latitude, 0);
    expect(report.longitude, 0);
  });
}
