import 'package:drift/drift.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_faults_table.dart';

part 'pmcs_faults_dao.g.dart';

@DriftAccessor(tables: [PmcsFaults])
class PmcsFaultsDao extends DatabaseAccessor<AppDatabase>
    with _$PmcsFaultsDaoMixin {
  PmcsFaultsDao(super.db);

  Future<List<PmcsFaultData>> getForSession(String sessionId) {
    return (select(pmcsFaults)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
        .get();
  }

  Future<void> replacePhaseFaults(
    String sessionId,
    String phase,
    List<PmcsFaultsCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(pmcsFaults)
            ..where(
                (t) => t.sessionId.equals(sessionId) & t.phase.equals(phase)))
          .go();
      await batch((b) => b.insertAll(pmcsFaults, rows));
    });
  }

  Future<void> deleteForSession(String sessionId) async {
    await (delete(pmcsFaults)..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }
}
