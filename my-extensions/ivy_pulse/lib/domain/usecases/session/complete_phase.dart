import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';
import 'package:ivy_pulse/domain/usecases/faults/build_phase_faults.dart';

class CompletePhaseOutcome {
  final PmcsSession session;
  final List<PmcsFault> faults;

  const CompletePhaseOutcome({required this.session, required this.faults});

  FaultTally get tally => FaultTally.from(faults);
}

/// Closes out a phase: derives its faults, replaces any stored from an earlier
/// pass, and marks the phase done on the session.
class CompletePhase {
  final SessionsRepository sessionsRepository;
  final FaultsRepository faultsRepository;
  final BuildPhaseFaults buildPhaseFaults;

  const CompletePhase({
    required this.sessionsRepository,
    required this.faultsRepository,
    this.buildPhaseFaults = const BuildPhaseFaults(),
  });

  Future<CompletePhaseOutcome> call({
    required PmcsSession session,
    required PmcsPhase phase,
    required PmcsCatalog catalog,
    required Map<String, CheckResult> results,
  }) async {
    final faults = buildPhaseFaults(
      sessionId: session.sessionId,
      phase: phase,
      catalog: catalog,
      results: results,
    );

    await faultsRepository.replacePhaseFaults(
      session.sessionId,
      faults,
      phaseWireName: phase.wireName,
    );

    final updated = session.withPhaseCompleted(phase);
    await sessionsRepository.update(updated);

    return CompletePhaseOutcome(session: updated, faults: faults);
  }
}
