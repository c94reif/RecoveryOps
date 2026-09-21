import 'package:ivy_pulse/domain/entities/pmcs_session.dart';

abstract class SessionsRepository {
  /// Sessions that still have phases left, newest first — the "continue where
  /// you left off" list.
  Future<List<PmcsSession>> getOpenSessions();

  Future<PmcsSession?> getBySessionId(String sessionId);

  /// Inserts and returns the session with its assigned row id.
  Future<PmcsSession> insert(PmcsSession session);

  Future<void> update(PmcsSession session);

  Future<void> deleteBySessionId(String sessionId);
}
