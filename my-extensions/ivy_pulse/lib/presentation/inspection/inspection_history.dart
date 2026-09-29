part of 'inspection_view_model.dart';

/// Previous reports and comparisons for the current inspection.
mixin _InspectionHistory on _InspectionState {
  @override
  Future<void> loadHistory() async {
    final current = session;
    history = null;
    historyUnavailable = false;
    if (current == null) return;
    try {
      final reports = await reportsRepository.getAllReports();
      final withdrawn = await reportsRepository.getWithdrawnIds();
      if (session?.sessionId != current.sessionId) return;
      history = PmcsHistory.forVehicle(
        reports.where((report) => !withdrawn.contains(report.entityId)),
        bumperNumber: current.bumperNumber,
        uic: current.uic,
        vehicleType: current.vehicleType,
        before: current.startedAt,
        excluding: current.sessionId,
      );
    } catch (_) {
      historyUnavailable = true;
    }
    await suggestions.load();
  }

  List<HistoricalFault> get summarySuggestions =>
      history?.suggestedUnresolved
          .where((suggestion) =>
              session?.completedPhases.contains(suggestion.fault.phase) != true)
          .toList() ??
      const [];

  List<PhaseComparison> get comparisons => [
        if (history != null)
          for (final phase in session?.completedPhases ?? <PmcsPhase>[])
            history!.compare(phase, sessionFaults),
      ];
}
