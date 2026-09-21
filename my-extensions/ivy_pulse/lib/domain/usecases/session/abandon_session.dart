import 'package:ivy_pulse/domain/repositories/faults_repo.dart';
import 'package:ivy_pulse/domain/repositories/results_repo.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';

/// Discards an in-progress PMCS and everything recorded under it.
class AbandonSession {
  final SessionsRepository sessionsRepository;
  final ResultsRepository resultsRepository;
  final FaultsRepository faultsRepository;

  const AbandonSession({
    required this.sessionsRepository,
    required this.resultsRepository,
    required this.faultsRepository,
  });

  Future<void> call(String sessionId) async {
    await faultsRepository.deleteForSession(sessionId);
    await resultsRepository.deleteForSession(sessionId);
    await sessionsRepository.deleteBySessionId(sessionId);
  }
}
