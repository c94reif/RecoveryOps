import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/usecases/session/abandon_session.dart';

import '../../../support/fakes.dart';

void main() {
  test('clears the session and everything recorded under it', () async {
    final sessions = FakeSessionsRepository();
    final results = FakeResultsRepository();
    final faults = FakeFaultsRepository();

    await sessions.insert(buildSession());
    await faults.replacePhaseFaults(
      'session-1',
      [buildFault()],
      phaseWireName: PmcsPhase.before.wireName,
    );

    await AbandonSession(
      sessionsRepository: sessions,
      resultsRepository: results,
      faultsRepository: faults,
    )('session-1');

    expect(sessions.sessions, isEmpty);
    expect(await faults.getForSession('session-1'), isEmpty);
    expect(results.clearedSessions, ['session-1']);
  });
}
