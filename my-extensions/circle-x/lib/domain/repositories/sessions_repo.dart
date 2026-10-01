import 'package:circle_x/domain/entities/pmcs_session.dart';

abstract class SessionsRepository {
  Future<List<PmcsSession>> getOpenSessions();

  Future<PmcsSession?> getBySessionId(String sessionId);

  Future<PmcsSession> insert(PmcsSession session);

  Future<void> update(PmcsSession session);

  Future<void> updateLocation(
      String sessionId, double latitude, double longitude);

  Future<void> deleteBySessionId(String sessionId);
}
