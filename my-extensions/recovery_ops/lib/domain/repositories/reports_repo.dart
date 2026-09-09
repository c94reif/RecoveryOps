import 'package:recovery_ops/domain/entities/recovery_report.dart';

abstract class ReportsRepository {
  Future<List<RecoveryReport>> getAllReports();
  Future<void> insertReport(RecoveryReport report);
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude);
  Future<void> clearNavigatorLocation(int id);
  Future<void> markAsRead(int id);
  Future<void> markAllAsRead();
  Future<void> updateRouteGeometry(int id, String geometryJson);
  Future<void> deleteReport(int id);
}
