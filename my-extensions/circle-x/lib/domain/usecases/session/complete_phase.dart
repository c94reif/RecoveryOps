import 'package:circle_x/domain/services/transaction_runner.dart';
import 'package:circle_x/domain/entities/check_result.dart';
import 'package:circle_x/domain/entities/pmcs_catalog.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/repositories/faults_repo.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';
import 'package:circle_x/domain/usecases/faults/build_phase_faults.dart';

class CompletePhaseOutcome {
  final PmcsSession session;
  final List<PmcsFault> faults;

  const CompletePhaseOutcome({required this.session, required this.faults});

  FaultTally get tally => FaultTally.from(faults);
}

class CompletePhase {
  final TransactionRunner transactionRunner;
  final SessionsRepository sessionsRepository;
  final FaultsRepository faultsRepository;
  final BuildPhaseFaults buildPhaseFaults;

  const CompletePhase({
    required this.transactionRunner,
    required this.sessionsRepository,
    required this.faultsRepository,
    this.buildPhaseFaults = const BuildPhaseFaults(),
  });

  Future<CompletePhaseOutcome> call({
    required PmcsSession session,
    required PmcsPhase phase,
    required PmcsCatalog catalog,
    required Map<String, CheckResult> results,
  }) =>
      transactionRunner.run(() async {
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
      });
}
