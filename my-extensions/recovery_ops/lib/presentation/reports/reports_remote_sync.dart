part of 'reports_view_model.dart';

/// Reconciles remote records and permanent withdrawals with local report state.
mixin _RemoteReportSync on ChangeNotifier {
  ReportsRepository get repository;
  SyncRemoteReports get syncRemoteReports;
  SyncLocalReportsToLattice get syncLocalReportsToLattice;
  List<RecoveryReport> get reports;
  void updateUnread();

  Future<void> applyRemoteDeletion(String entityId) async {
    final stored = await repository.getAllReports();
    for (final report in stored) {
      if (report.entityId == entityId && report.id != null) {
        await repository.deleteReport(report.id!);
      }
    }
    reports.removeWhere((r) => r.entityId == entityId);
    updateUnread();
    notifyListeners();
  }

  Future<void> syncRemoteLatticeReports() async {
    try {
      for (final id in await syncRemoteReports.fetchWithdrawnIds()) {
        await applyRemoteDeletion(id);
      }
    } catch (error) {
      debugPrint('[RecoveryOps] Report withdrawals sync failed: $error');
      return;
    }
    final newReports = await syncRemoteReports(reports);
    if (newReports.isNotEmpty) {
      for (final report in newReports) {
        reports.insert(0, report);
      }
      updateUnread();
      notifyListeners();
    }

    await syncLocalReportsToLattice(reports);
  }
}
