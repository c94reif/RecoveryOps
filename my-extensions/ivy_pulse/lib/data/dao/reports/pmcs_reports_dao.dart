import 'package:drift/drift.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/datasources/local/tables/pmcs_reports_table.dart';

part 'pmcs_reports_dao.g.dart';

@DriftAccessor(tables: [PmcsReports])
class PmcsReportsDao extends DatabaseAccessor<AppDatabase>
    with _$PmcsReportsDaoMixin {
  PmcsReportsDao(super.db);

  Future<List<PmcsReportData>> getAllReports() {
    return (select(pmcsReports)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
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
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required bool isOutgoing,
    required bool isRead,
  }) async {
    return into(pmcsReports).insert(
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
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        isOutgoing: Value(isOutgoing),
        isRead: Value(isRead),
      ),
    );
  }

  Future<void> markAsRead(int id) async {
    await (update(pmcsReports)..where((t) => t.id.equals(id))).write(
      const PmcsReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllAsRead() async {
    await (update(pmcsReports)..where((t) => t.isRead.equals(false))).write(
      const PmcsReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> deleteReport(int id) async {
    await (delete(pmcsReports)..where((record) => record.id.equals(id))).go();
  }
}
