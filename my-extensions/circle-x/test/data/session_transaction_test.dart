import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/dao/faults/pmcs_faults_dao.dart';
import 'package:circle_x/data/dao/results/check_results_dao.dart';
import 'package:circle_x/data/dao/sessions/sessions_dao.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/repositories/faults_repo_impl.dart';
import 'package:circle_x/data/repositories/results_repo_impl.dart';
import 'package:circle_x/data/repositories/sessions_repo_impl.dart';
import 'package:circle_x/data/services/drift_transaction_runner.dart';
import 'package:circle_x/domain/entities/check_result.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/usecases/session/abandon_session.dart';
import 'package:circle_x/domain/usecases/session/complete_phase.dart';

import '../support/fakes.dart';

class FailingSessionsRepository extends SessionsRepoImpl {
  FailingSessionsRepository(super.dao);

  @override
  Future<void> update(PmcsSession session) async {
    await super.update(session);
    throw StateError('Session update failed');
  }

  @override
  Future<void> deleteBySessionId(String sessionId) async {
    await super.deleteBySessionId(sessionId);
    throw StateError('Session deletion failed');
  }
}

void main() {
  late AppDatabase database;
  late SessionsRepoImpl sessions;
  late FaultsRepoImpl faults;
  late ResultsRepoImpl results;
  late DriftTransactionRunner transaction;
  late PmcsSession session;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    sessions = FailingSessionsRepository(SessionsDao(database));
    faults = FaultsRepoImpl(PmcsFaultsDao(database));
    results = ResultsRepoImpl(CheckResultsDao(database));
    transaction = DriftTransactionRunner(database);
    session = await sessions.insert(buildSession());
    await faults.replacePhaseFaults(session.sessionId, [buildFault()],
        phaseWireName: PmcsPhase.before.wireName);
    await results.upsertResult(
      session.sessionId,
      PmcsPhase.before,
      CheckResult(
        itemId: 'B-ENG-01',
        faultIndex: 1,
        faultLabel: 'Low-Add Oil',
        severity: FaultSeverity.circleX,
        recordedAt: session.startedAt,
      ),
    );
  });

  tearDown(() => database.close());

  test('phase completion rolls back faults and session together', () async {
    final complete = CompletePhase(
      transactionRunner: transaction,
      sessionsRepository: sessions,
      faultsRepository: faults,
    );
    await expectLater(
      complete(
        session: session,
        phase: PmcsPhase.before,
        catalog:
            const PmcsCatalog(vehicleType: VehicleType.stryker, phases: {}),
        results: const {},
      ),
      throwsStateError,
    );
    final persisted = await sessions.getBySessionId(session.sessionId);
    expect(persisted!.completedPhases, isEmpty);
    expect(await faults.getForSession(session.sessionId), hasLength(1));
  });

  test('abandoning a session rolls back all child deletions on failure',
      () async {
    final abandon = AbandonSession(
      transactionRunner: transaction,
      sessionsRepository: sessions,
      faultsRepository: faults,
      resultsRepository: results,
    );
    await expectLater(abandon(session.sessionId), throwsStateError);
    expect(await sessions.getBySessionId(session.sessionId), isNotNull);
    expect(await faults.getForSession(session.sessionId), hasLength(1));
    expect(await results.getResults(session.sessionId, PmcsPhase.before),
        contains('B-ENG-01'));
  });
}
