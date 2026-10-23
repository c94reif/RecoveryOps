import 'package:circle_x/domain/inspection/entities/pmcs_session.dart';
import 'package:circle_x/domain/inspection/repositories/sessions_repo.dart';

class LoadOpenSessions {
  final SessionsRepository repository;

  const LoadOpenSessions(this.repository);

  Future<List<PmcsSession>> call() => repository.getOpenSessions();
}
