import 'package:circle_x/domain/entities/pmcs_history.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

/// Queries the current reports and suggestion preferences without owning them.
class ReportBrowser {
  final ReportsViewModel viewModel;

  const ReportBrowser(this.viewModel);

  Map<ReportVehicleKey, List<PmcsReport>> filterGroups(
    List<PmcsReport> reports, {
    required String search,
    required bool faultsOnly,
    required bool unreadOnly,
  }) {
    final query = search.trim().toUpperCase();
    return Map.fromEntries(
        viewModel.groupByVehicle(reports).entries.where((entry) {
      final vehicle = entry.key;
      return (query.isEmpty ||
              vehicle.bumperNumber.contains(query) ||
              vehicle.uic.contains(query)) &&
          (!faultsOnly ||
              entry.value.first.faults.isNotEmpty ||
              visibleSuggestionsFor(entry.value.first).isNotEmpty) &&
          (!unreadOnly ||
              entry.value
                  .any((report) => !report.isOutgoing && !report.isRead));
    }));
  }

  PmcsHistory historyFor(PmcsReport report, {bool previousOnly = false}) =>
      PmcsHistory.forVehicle(
        viewModel.reports.where((candidateReport) =>
            !candidateReport.timestamp.isAfter(report.timestamp)),
        bumperNumber: report.bumperNumber,
        uic: report.uic,
        vehicleType: report.vehicleType,
        before: previousOnly ? report.timestamp : null,
        excluding: previousOnly ? report.entityId : null,
      );

  List<HistoricalFault> suggestionsFor(PmcsReport report) => historyFor(report)
      .suggestedUnresolved
      .where((suggestion) => suggestion.report.entityId != report.entityId)
      .toList();

  List<HistoricalFault> visibleSuggestionsFor(PmcsReport report) =>
      suggestionsFor(report)
          .where((suggestion) => !viewModel.suggestions.dismissed
              .contains(suggestion.suggestionId))
          .toList();
}
