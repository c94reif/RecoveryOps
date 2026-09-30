part of 'reports_view_model.dart';

/// Cached report views, vehicle grouping, and unread counts.
mixin _ReportsCollection on _ReportsState {
  @override
  void invalidateReportViews() {
    cachedYours = cachedExternal = cachedUnit = cachedOther = null;
  }

  @override
  void updateUnread() {
    invalidateReportViews();
    unreadCount.value = reports
        .where((candidateReport) =>
            !candidateReport.isRead && !candidateReport.isOutgoing)
        .length;
  }

  List<PmcsReport> get yourReports => cachedYours ??= List.unmodifiable(
      reports.where((candidateReport) => candidateReport.isOutgoing));

  List<PmcsReport> get externalReports => cachedExternal ??= List.unmodifiable(
      reports.where((candidateReport) => !candidateReport.isOutgoing));

  bool isSameUnit(PmcsReport report) =>
      myUic.isEmpty || report.uic.trim().toUpperCase() == myUic;

  List<PmcsReport> get unitReports =>
      cachedUnit ??= List.unmodifiable(externalReports.where(isSameUnit));

  List<PmcsReport> get otherUnitReports => cachedOther ??= List.unmodifiable(
      externalReports.where((candidateReport) => !isSameUnit(candidateReport)));

  Map<ReportVehicleKey, List<PmcsReport>> groupByVehicle(
      List<PmcsReport> source) {
    final cacheable = identical(source, cachedYours) ||
        identical(source, cachedExternal) ||
        identical(source, cachedUnit) ||
        identical(source, cachedOther);
    if (cacheable && vehicleGroups[source] != null) {
      return vehicleGroups[source]!;
    }
    final groups = <ReportVehicleKey, List<PmcsReport>>{};
    for (final report in source) {
      final vehicle = (
        bumperNumber: report.bumperNumber.trim().toUpperCase(),
        uic: report.uic.trim().toUpperCase(),
      );
      groups.putIfAbsent(vehicle, () => []).add(report);
    }
    for (final list in groups.values) {
      list.sort((first, second) => second.timestamp.compareTo(first.timestamp));
    }
    final keys = groups.keys.toList()
      ..sort((first, second) {
        final bumperOrder = first.bumperNumber.compareTo(second.bumperNumber);
        return bumperOrder != 0 ? bumperOrder : first.uic.compareTo(second.uic);
      });
    final sorted = {for (final key in keys) key: groups[key]!};
    if (cacheable) vehicleGroups[source] = sorted;
    return sorted;
  }

  Map<String, List<QueuedSubmission>> get queuedByBumperNumber {
    final groups = <String, List<QueuedSubmission>>{};
    for (final submission in queued) {
      final bumper = submission.bumperNumber.trim().toUpperCase();
      groups.putIfAbsent(bumper, () => []).add(submission);
    }
    for (final list in groups.values) {
      list.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    }
    final keys = groups.keys.toList()
      ..sort((first, second) => groups[second]!
          .first
          .createdAt
          .compareTo(groups[first]!.first.createdAt));
    return {for (final key in keys) key: groups[key]!};
  }

  String bucketFor(PmcsReport report) {
    final tally = report.tally;
    if (tally.redX > 0) return ReportsViewModel.bucketNotMissionCapable;
    if (tally.circleX > 0) return ReportsViewModel.bucketLimited;
    return ReportsViewModel.bucketMissionCapable;
  }

  Map<String, List<PmcsReport>> get groupedByStatus {
    final result = {
      for (final bucket in ReportsViewModel.statusBuckets)
        bucket: <PmcsReport>[],
    };
    for (final report in externalReports) {
      result[bucketFor(report)]!.add(report);
    }
    for (final list in result.values) {
      list.sort((first, second) => second.timestamp.compareTo(first.timestamp));
    }
    return result;
  }
}
