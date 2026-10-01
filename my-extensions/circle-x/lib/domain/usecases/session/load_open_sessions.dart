import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/repositories/sessions_repo.dart';

class LoadOpenSessions {
  final SessionsRepository repository;

  const LoadOpenSessions(this.repository);

  Future<List<PmcsSession>> call() => repository.getOpenSessions();
}
