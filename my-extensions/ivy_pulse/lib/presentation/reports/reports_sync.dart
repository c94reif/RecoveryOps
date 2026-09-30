part of 'reports_view_model.dart';

/// Database loading, incoming messages, withdrawals, and remote polling.
mixin _ReportsSync on _ReportsState {
  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    final withdrawn = await repository.getWithdrawnIds();
    if (disposed) return;
    final knownEntityIds =
        reports.map((candidateReport) => candidateReport.entityId).toSet();
    for (final row in rows) {
      if (withdrawn.contains(row.entityId)) continue;
      if (knownEntityIds.add(row.entityId)) reports.add(row);
    }
    await loadMyUic();
    if (disposed) return;
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
    await refreshQueued();
  }

  Future<void> loadMyUic() async {
    try {
      final profile = await profileRepository.getProfile();
      myUic = (profile?.uic ?? '').trim().toUpperCase();
      invalidateReportViews();
    } catch (error) {
      debugPrint('[IvyPulse] could not read UIC for report filtering: $error');
    }
  }

  void onMessage(IncomingReportMessage message) {
    final report = parseIncomingReport(message);
    if (report != null) {
      unawaited(storeIncomingReport(report));
      return;
    }

    final deletedEntityId = parseIncomingDeletion(message);
    if (deletedEntityId != null) {
      applyRemoteDeletion(deletedEntityId);
    }
  }

  Future<void> storeIncomingReport(PmcsReport report) async {
    try {
      final stored = await repository.insertReport(report);
      if (disposed ||
          (await repository.getWithdrawnIds()).contains(stored.entityId)) {
        return;
      }
      if (disposed) return;
      reports.removeWhere(
          (candidateReport) => candidateReport.entityId == stored.entityId);
      reports.insert(0, stored);
      updateUnread();
      notifyListeners();
    } on ReportWithdrawn {
      return;
    } catch (error) {
      debugPrint('[IvyPulse] Could not store incoming report: $error');
    }
  }

  Future<void> applyRemoteDeletion(String entityId) async {
    try {
      await repository.withdrawReport(entityId);
      if (disposed) return;
      reports.removeWhere(
          (candidateReport) => candidateReport.entityId == entityId);
      updateUnread();
      notifyListeners();
    } catch (error) {
      debugPrint('[IvyPulse] Could not store withdrawal: $error');
    }
  }

  void startRemoteSyncPolling() {
    remoteSyncTimer = Timer.periodic(
      AppConstants.remoteSyncInterval,
      (_) => unawaited(syncRemoteLatticeReports().catchError((Object error) {
        debugPrint('[IvyPulse] Scheduled sync failed: $error');
      })),
    );
  }

  Future<void> syncRemoteLatticeReports() =>
      syncInFlight ??= performRemoteSync().whenComplete(() {
        syncInFlight = null;
      });

  Future<void> performRemoteSync() async {
    final newReports = await syncRemoteReports(reports);
    final withdrawn = await repository.getWithdrawnIds();
    if (disposed) return;
    if (newReports.isNotEmpty || withdrawn.isNotEmpty) {
      reports.removeWhere(
          (candidateReport) => withdrawn.contains(candidateReport.entityId));
      for (final report in newReports) {
        if (withdrawn.contains(report.entityId)) continue;
        reports.removeWhere(
            (candidateReport) => candidateReport.entityId == report.entityId);
        reports.insert(0, report);
      }
      updateUnread();
      notifyListeners();
    }

    await syncLocalReportsToLattice(reports);
    await refreshQueuedCount();
    await refreshQueued();
  }
}
