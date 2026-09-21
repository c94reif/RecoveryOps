import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';

/// The "continue where you left off" list: PMCS runs this operator started but
/// has not submitted.
class LoadOpenSessions {
  final SessionsRepository repository;

  const LoadOpenSessions(this.repository);

  Future<List<PmcsSession>> call() => repository.getOpenSessions();
}
