import 'package:circle_x/domain/services/transaction_runner.dart';
import 'package:circle_x/domain/repositories/faults_repo.dart';
import 'package:circle_x/domain/repositories/results_repo.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';

class AbandonSession {
  final TransactionRunner transactionRunner;
  final SessionsRepository sessionsRepository;
  final ResultsRepository resultsRepository;
  final FaultsRepository faultsRepository;

  const AbandonSession({
    required this.transactionRunner,
    required this.sessionsRepository,
    required this.resultsRepository,
    required this.faultsRepository,
  });

  Future<void> call(String sessionId) => transactionRunner.run(() async {
        await faultsRepository.deleteForSession(sessionId);
        await resultsRepository.deleteForSession(sessionId);
        await sessionsRepository.deleteBySessionId(sessionId);
      });
}
