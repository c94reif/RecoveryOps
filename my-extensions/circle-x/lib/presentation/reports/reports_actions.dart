part of 'reports_view_model.dart';

/// User actions on reports: reading, deleting, and map display.
mixin _ReportsActions on _ReportsState {
  Future<void> addOutgoing(PmcsReport stored) async {
    reports.removeWhere(
        (candidateReport) => candidateReport.entityId == stored.entityId);
    reports.insert(0, stored);
    updateUnread();
    notifyListeners();
    await refreshQueuedCount();
    await refreshQueued();
  }

  Future<void> markReportAsRead(PmcsReport report) async {
    if (report.isRead) return;
    final index = reports.indexOf(report);
    if (index == -1) return;
    reports[index] = report.copyWith(isRead: true);
    updateUnread();
    if (report.id != null) {
      await repository.markAsRead(report.id!);
    }
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var reportIndex = 0; reportIndex < reports.length; reportIndex++) {
      if (!reports[reportIndex].isRead) {
        reports[reportIndex] = reports[reportIndex].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      updateUnread();
      await repository.markAllAsRead();
      notifyListeners();
    }
  }

  Future<void> deleteReport(PmcsReport report) async {
    if (!reports.contains(report)) return;
    if (report.isOutgoing && report.entityId.isNotEmpty) {
      try {
        final outcome = await publishPmcsDeletion(report);
        snackBarService.enqueue(
          'Withdrawal — Lattice: ${outcome.latticeOk ? 'sent' : 'queued'} | '
          'Mesh: ${outcome.meshOk ? 'sent' : 'queued'}',
          isError: !outcome.allSucceeded,
        );
      } catch (error) {
        snackBarService.enqueue('Could not save withdrawal. Please retry.',
            isError: true);
        return;
      }
    } else if (report.id != null) {
      await repository.deleteReport(report.id!);
    }
    if (disposed) return;
    reports.removeWhere(
        (candidateReport) => candidateReport.entityId == report.entityId);
    updateUnread();
    notifyListeners();
    await refreshQueued();
  }

  Future<void> viewReport(PmcsReport report) async {
    activeMarkerId = await showReportOnMap(
      report,
      previousMarkerId: activeMarkerId,
    );
    notifyListeners();
  }
}
