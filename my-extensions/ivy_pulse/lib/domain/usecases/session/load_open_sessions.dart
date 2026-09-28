import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/repositories/sessions_repo.dart';

class LoadOpenSessions {
  final SessionsRepository repository;

  const LoadOpenSessions(this.repository);

  Future<List<PmcsSession>> call() => repository.getOpenSessions();
}
