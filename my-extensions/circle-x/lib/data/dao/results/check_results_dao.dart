import 'package:drift/drift.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/datasources/local/tables/check_results_table.dart';

part 'check_results_dao.g.dart';

@DriftAccessor(tables: [CheckResults])
class CheckResultsDao extends DatabaseAccessor<AppDatabase>
    with _$CheckResultsDaoMixin {
  CheckResultsDao(super.db);

  Future<List<CheckResultData>> getResults(String sessionId, String phase) {
    return (select(checkResults)
          ..where((table) =>
              table.sessionId.equals(sessionId) & table.phase.equals(phase)))
        .get();
  }

  Future<void> upsertResult({
    required String sessionId,
    required String phase,
    required String itemId,
    required int faultIndex,
    required String faultLabel,
    String? severity,
    String? note,
    required DateTime recordedAt,
  }) async {
    final row = CheckResultsCompanion.insert(
      sessionId: sessionId,
      phase: phase,
      itemId: itemId,
      faultIndex: faultIndex,
      faultLabel: faultLabel,
      severity: Value(severity),
      note: Value(note),
      recordedAt: recordedAt,
    );

    await into(checkResults).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        target: [
          checkResults.sessionId,
          checkResults.phase,
          checkResults.itemId,
        ],
      ),
    );
  }

  Future<void> deleteForSession(String sessionId) async {
    await (delete(checkResults)
          ..where((table) => table.sessionId.equals(sessionId)))
        .go();
  }
}
