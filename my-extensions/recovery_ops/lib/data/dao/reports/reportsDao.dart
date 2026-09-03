import 'package:drift/drift.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/datasources/local/tables/reportsTable.dart';

part 'reportsDao.g.dart';

@DriftAccessor(tables: [Reports])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Future<List<ReportData>> getAllReports() {
    return (select(reports)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
  }

  Future<void> insertReport({
    String? entityId,
    required String fromCallsign,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
    double? navigatorLatitude,
    double? navigatorLongitude,
    required DateTime timestamp,
    required bool isOutgoing,
    required bool isRead,
  }) async {
    await into(reports).insert(
      ReportsCompanion.insert(
        entityId: Value(entityId),
        fromCallsign: fromCallsign,
        bumperNumber: bumperNumber,
        issue: issue,
        recoveryType: recoveryType,
        latitude: latitude,
        longitude: longitude,
        navigatorLatitude: Value(navigatorLatitude),
        navigatorLongitude: Value(navigatorLongitude),
        timestamp: timestamp,
        isOutgoing: Value(isOutgoing),
        isRead: Value(isRead),
      ),
    );
  }

  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {
    await (update(reports)..where((t) => t.id.equals(id))).write(
      ReportsCompanion(
        navigatorLatitude: Value(latitude),
        navigatorLongitude: Value(longitude),
      ),
    );
  }

  Future<void> clearNavigatorLocation(int id) async {
    await (update(reports)..where((t) => t.id.equals(id))).write(
      const ReportsCompanion(
        navigatorLatitude: Value(null),
        navigatorLongitude: Value(null),
      ),
    );
  }

  Future<void> markAsRead(int id) async {
    await (update(reports)
      ..where((t) => t.id.equals(id))).write(
      const ReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllAsRead() async {
    await (update(reports)
      ..where((t) => t.isRead.equals(false))).write(
      const ReportsCompanion(isRead: Value(true)),
    );
  }

  Future<void> updateRouteGeometry(int id, String geometryJson) async {
    await (update(reports)..where((t) => t.id.equals(id))).write(
      ReportsCompanion(routeGeometry: Value(geometryJson)),
    );
  }

  Future<void> deleteReport(int id) async {
    await (delete(reports)
      ..where((record) => record.id.equals(id))).go();
  }
}
