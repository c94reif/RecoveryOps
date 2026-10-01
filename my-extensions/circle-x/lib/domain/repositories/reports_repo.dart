import 'package:circle_x/domain/entities/pmcs_report.dart';

abstract class ReportsRepository {
  Future<List<PmcsReport>> getAllReports();
  Future<PmcsReport> insertReport(PmcsReport report);
  Future<void> markAsRead(int id);
  Future<void> markAllAsRead();
  Future<void> deleteReport(int id);
  Future<Set<String>> getWithdrawnIds();
  Future<void> withdrawReport(String entityId);
  Future<Set<String>> getDismissedFaultSuggestions();
  Future<void> setFaultSuggestionDismissed(String suggestionId, bool dismissed);
}

class ReportWithdrawn implements Exception {
  final String entityId;
  const ReportWithdrawn(this.entityId);
}
