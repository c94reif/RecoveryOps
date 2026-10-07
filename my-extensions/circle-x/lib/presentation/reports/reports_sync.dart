part of 'reports_view_model.dart';

/// Database loading, incoming messages, withdrawals, and remote polling.
mixin _ReportsSync on _ReportsState {
  Future<void> loadFromDb() async {
    final rows = await repository.getAllReports();
    final withdrawn = await repository.getWithdrawnIds();
    if (disposed) return;
    final knownEntityIds =
        reports.map((candidateReport) => candidateReport.entityId).toSet();
    var addedReports = false;
    for (final row in rows) {
      if (withdrawn.contains(row.entityId)) continue;
      if (knownEntityIds.add(row.entityId)) {
        reports.add(row);
        addedReports = true;
      }
    }
    // An eager lifecycle wake may already have snapshotted the empty list.
    if (addedReports && syncInFlight != null) syncAgain = true;
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
      if (disposed) return;
      myUic = Uic.normalize(profile?.uic ?? '');
      reportUnits = profile?.reportUnits ?? const [];
      updateUnread();
      notifyListeners();
    } catch (error) {
      debugPrint('[CircleX] could not read UIC for report filtering: $error');
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
    if (disposed) return;
    try {
      final stored = await storeReceivedReport(repository, report);
      final withdrawn = await repository.getWithdrawnIds();
      if (disposed) return;
      for (final record in stored) {
        if (withdrawn.contains(record.entityId)) continue;
        reports.removeWhere(
            (candidateReport) => candidateReport.entityId == record.entityId);
        reports.insert(0, record);
      }
      updateUnread();
      notifyListeners();
      // Received records are durable before relay. Reconcile even when this
      // screen is not mounted, without rebroadcasting the peer's report.
      syncAgain = true;
      unawaited(syncRemoteLatticeReports());
    } on ReportWithdrawn {
      return;
    } catch (error) {
      debugPrint('[CircleX] Could not store incoming report: $error');
    }
  }

  Future<void> applyRemoteDeletion(String entityId) async {
    if (disposed) return;
    try {
      await repository.withdrawReport(entityId);
      if (disposed) return;
      reports.removeWhere(
          (candidateReport) => candidateReport.entityId == entityId);
      updateUnread();
      notifyListeners();
      syncAgain = true;
      unawaited(syncRemoteLatticeReports());
    } catch (error) {
      debugPrint('[CircleX] Could not store withdrawal: $error');
    }
  }

  void startRemoteSyncPolling() {
    remoteSyncTimer = Timer.periodic(
      AppConstants.remoteSyncInterval,
      (_) => unawaited(syncRemoteLatticeReports().catchError((Object error) {
        debugPrint('[CircleX] Scheduled sync failed: $error');
      })),
    );
  }

  Future<void> syncRemoteLatticeReports() {
    if (disposed) return Future.value();
    return syncInFlight ??= reconcileUntilCurrent().whenComplete(() {
      syncInFlight = null;
    });
  }

  Future<void> reconcileUntilCurrent() async {
    do {
      syncAgain = false;
      try {
        await performRemoteSync();
      } catch (error) {
        debugPrint('[CircleX] Report reconciliation failed: $error');
      }
    } while (syncAgain && !disposed);
  }

  Future<void> performRemoteSync() async {
    if (disposed) return;
    final newReports = await syncRemoteReports(reports);
    if (disposed) return;
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
