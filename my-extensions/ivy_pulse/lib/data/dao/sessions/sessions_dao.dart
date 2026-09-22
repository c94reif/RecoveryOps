import 'package:drift/drift.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_sessions_table.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [PmcsSessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  Future<List<PmcsSessionData>> getOpenSessions() {
    return (select(pmcsSessions)
          ..where((t) => t.status.equals(SessionStatus.inProgress.wireName))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<PmcsSessionData?> getBySessionId(String sessionId) {
    return (select(pmcsSessions)..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
  }

  Future<int> insertSession({
    required String sessionId,
    required String bumperNumber,
    required String vehicleType,
    required String operator,
    required String uic,
    required DateTime startedAt,
    DateTime? submittedAt,
    required String completedPhases,
    required String status,
    String? signatureJson,
    double? latitude,
    double? longitude,
  }) async {
    return into(pmcsSessions).insert(
      PmcsSessionsCompanion.insert(
        sessionId: sessionId,
        bumperNumber: bumperNumber,
        vehicleType: vehicleType,
        operator: operator,
        uic: uic,
        startedAt: startedAt,
        submittedAt: Value(submittedAt),
        completedPhases: Value(completedPhases),
        status: Value(status),
        signatureJson: Value(signatureJson),
        latitude: Value(latitude),
        longitude: Value(longitude),
      ),
    );
  }

  Future<void> updateSession({
    required String sessionId,
    required String bumperNumber,
    required String vehicleType,
    required String operator,
    required String uic,
    DateTime? submittedAt,
    required String completedPhases,
    required String status,
    String? signatureJson,
    double? latitude,
    double? longitude,
  }) async {
    final changed = await (update(pmcsSessions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .write(
      PmcsSessionsCompanion(
        bumperNumber: Value(bumperNumber),
        vehicleType: Value(vehicleType),
        operator: Value(operator),
        uic: Value(uic),
        submittedAt: Value(submittedAt),
        completedPhases: Value(completedPhases),
        status: Value(status),
        signatureJson: Value(signatureJson),
        latitude: Value.absentIfNull(latitude),
        longitude: Value.absentIfNull(longitude),
      ),
    );
    if (changed != 1) throw StateError('Inspection no longer exists');
  }

  Future<void> updateLocation(
      String sessionId, double latitude, double longitude) async {
    await (update(pmcsSessions)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.status.equals(SessionStatus.inProgress.wireName)))
        .write(
      PmcsSessionsCompanion(
          latitude: Value(latitude), longitude: Value(longitude)),
    );
  }

  Future<void> deleteBySessionId(String sessionId) async {
    await (delete(pmcsSessions)..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }
}
