import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';

import '../../support/fakes.dart';

void main() {
  test('a fresh session has every phase remaining', () {
    final session = buildSession();

    expect(session.completedPhases, isEmpty);
    expect(session.remainingPhases, PmcsPhase.values);
    expect(session.allPhasesComplete, isFalse);
    expect(session.hasStartedAnyPhase, isFalse);
  });

  test('withPhaseCompleted marks a phase done', () {
    final session = buildSession().withPhaseCompleted(PmcsPhase.before);

    expect(session.isPhaseComplete(PmcsPhase.before), isTrue);
    expect(session.isPhaseComplete(PmcsPhase.during), isFalse);
    expect(session.remainingPhases, [PmcsPhase.during, PmcsPhase.after]);
  });

  test('completing the same phase twice does not duplicate it', () {
    final session = buildSession()
        .withPhaseCompleted(PmcsPhase.before)
        .withPhaseCompleted(PmcsPhase.before);

    expect(session.completedPhases, [PmcsPhase.before]);
  });

  test('completed phases stay in TM order regardless of completion order', () {
    final session = buildSession()
        .withPhaseCompleted(PmcsPhase.after)
        .withPhaseCompleted(PmcsPhase.before);

    expect(session.completedPhases, [PmcsPhase.before, PmcsPhase.after]);
  });

  test('all three phases complete the session', () {
    var session = buildSession();
    for (final phase in PmcsPhase.values) {
      session = session.withPhaseCompleted(phase);
    }

    expect(session.allPhasesComplete, isTrue);
    expect(session.remainingPhases, isEmpty);
  });

  test('copyWith preserves identity fields', () {
    final session = buildSession().copyWith(status: SessionStatus.submitted);

    expect(session.sessionId, 'session-1');
    expect(session.startedAt, DateTime.utc(2026, 3, 24, 6));
    expect(session.status, SessionStatus.submitted);
  });

  test('displayTitle names the vehicle', () {
    expect(buildSession().displayTitle, 'A-11 - Stryker');
  });
}
