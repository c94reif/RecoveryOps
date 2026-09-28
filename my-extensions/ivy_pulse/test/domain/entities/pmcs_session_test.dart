import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';

import '../../support/fakes.dart';

void main() {
  test('a fresh session has no completed inspection', () {
    final session = buildSession();

    expect(session.completedPhases, isEmpty);
    expect(session.hasStartedAnyPhase, isFalse);
  });

  test('withPhaseCompleted marks a phase done', () {
    final session = buildSession().withPhaseCompleted(PmcsPhase.before);

    expect(session.isPhaseComplete(PmcsPhase.before), isTrue);
    expect(session.isPhaseComplete(PmcsPhase.during), isFalse);
    expect(session.completedPhases, [PmcsPhase.before]);
    expect(session.hasStartedAnyPhase, isTrue);
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

  test('legacy sessions retain multiple completed inspection types', () {
    var session = buildSession();
    for (final phase in PmcsPhase.values) {
      session = session.withPhaseCompleted(phase);
    }

    expect(session.completedPhases, PmcsPhase.values);
    expect(session.status, SessionStatus.inProgress);
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
