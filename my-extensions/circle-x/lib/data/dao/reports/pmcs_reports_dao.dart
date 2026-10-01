import 'package:drift/drift.dart';
import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/data/datasources/local/tables/pmcs_reports_table.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';

part 'pmcs_reports_dao.g.dart';

@DriftAccessor(tables: [PmcsReports])
class PmcsReportsDao extends DatabaseAccessor<AppDatabase>
    with _$PmcsReportsDaoMixin {
  PmcsReportsDao(super.db);

  Future<Set<String>> getDismissedFaultSuggestions() async => {
        for (final row
            in await select(attachedDatabase.dismissedFaultSuggestions).get())
          row.suggestionId,
      };

  Future<void> setFaultSuggestionDismissed(String id, bool dismissed) async {
    final table = attachedDatabase.dismissedFaultSuggestions;
    if (dismissed) {
      await into(table).insert(
        DismissedFaultSuggestionsCompanion.insert(suggestionId: id),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (delete(table)
            ..where(
                (suggestionTable) => suggestionTable.suggestionId.equals(id)))
          .go();
    }
  }

  Future<List<PmcsReportData>> getAllReports() {
    return (select(pmcsReports)
          ..orderBy(
              [(reportTable) => OrderingTerm.desc(reportTable.timestamp)]))
        .get();
  }

  Future<int> insertReport({
    required String entityId,
    required String fromCallsign,
    required String bumperNumber,
    required String vehicleType,
    required String operator,
    required String uic,
    required String phases,
    required String faultsJson,
    String? signatureJson,
    String? maintainerReviewJson,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required bool isOutgoing,
    required bool isRead,
  }) =>
      transaction(() async {
        if ((await getWithdrawnIds()).contains(entityId)) {
          throw ReportWithdrawn(entityId);
        }
        await into(pmcsReports).insert(
          PmcsReportsCompanion.insert(
            entityId: entityId,
            fromCallsign: fromCallsign,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            operator: operator,
            uic: uic,
            phases: phases,
            faultsJson: faultsJson,
            signatureJson: Value(signatureJson),
            maintainerReviewJson: Value(maintainerReviewJson),
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            isOutgoing: Value(isOutgoing),
            isRead: Value(isRead),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        final row = await (select(pmcsReports)
              ..where((reportTable) => reportTable.entityId.equals(entityId))
              ..orderBy([(reportTable) => OrderingTerm.desc(reportTable.id)])
              ..limit(1))
            .getSingle();
        return row.id;
      });

  Future<Set<String>> getWithdrawnIds() async => {
        for (final row
            in await select(attachedDatabase.reportWithdrawals).get())
          row.entityId,
      };

  Future<void> withdrawReport(String entityId) => transaction(() async {
        await into(attachedDatabase.reportWithdrawals).insert(
          ReportWithdrawalsCompanion.insert(entityId: entityId),
          mode: InsertMode.insertOrIgnore,
        );
        await (delete(pmcsReports)
              ..where((reportTable) => reportTable.entityId.equals(entityId)))
            .go();
      });

  Future<PmcsReportData> getById(int id) =>
      (select(pmcsReports)..where((reportTable) => reportTable.id.equals(id)))
          .getSingle();

  Future<void> markAsRead(int id) async {
    await (update(pmcsReports)
          ..where((reportTable) => reportTable.id.equals(id)))
        .write(
      const PmcsReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllAsRead() async {
    await (update(pmcsReports)
          ..where((reportTable) => reportTable.isRead.equals(false)))
        .write(
      const PmcsReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> deleteReport(int id) async {
    await (delete(pmcsReports)..where((record) => record.id.equals(id))).go();
  }
}
