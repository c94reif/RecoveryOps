import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

abstract class ReportsRepository {
  Future<List<PmcsReport>> getAllReports();
  Future<PmcsReport> insertReport(PmcsReport report);
  Future<void> markAsRead(int id);
  Future<void> markAllAsRead();
  Future<void> deleteReport(int id);
}
