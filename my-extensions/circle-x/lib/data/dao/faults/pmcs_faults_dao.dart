import 'package:drift/drift.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/datasources/local/tables/pmcs_faults_table.dart';

part 'pmcs_faults_dao.g.dart';

@DriftAccessor(tables: [PmcsFaults])
class PmcsFaultsDao extends DatabaseAccessor<AppDatabase>
    with _$PmcsFaultsDaoMixin {
  PmcsFaultsDao(super.db);

  Future<List<PmcsFaultData>> getForSession(String sessionId) {
    return (select(pmcsFaults)
          ..where((table) => table.sessionId.equals(sessionId))
          ..orderBy([(table) => OrderingTerm.asc(table.recordedAt)]))
        .get();
  }

  Future<void> replacePhaseFaults(
    String sessionId,
    String phase,
    List<PmcsFaultsCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(pmcsFaults)
            ..where((table) =>
                table.sessionId.equals(sessionId) & table.phase.equals(phase)))
          .go();
      await batch((batchWriter) => batchWriter.insertAll(pmcsFaults, rows));
    });
  }

  Future<void> deleteForSession(String sessionId) async {
    await (delete(pmcsFaults)
          ..where((table) => table.sessionId.equals(sessionId)))
        .go();
  }
}
