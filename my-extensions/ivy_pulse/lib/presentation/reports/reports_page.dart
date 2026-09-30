import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/presentation/common/widgets/pmcs_report_card.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_history_widgets.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/reports/controllers/new_pmcs_controller.dart';
import 'package:ivy_pulse/presentation/reports/controllers/report_browser.dart';
import 'package:ivy_pulse/presentation/reports/widgets/report_navigation.dart';
import 'package:ivy_pulse/presentation/reports/widgets/report_queue_widgets.dart';
import 'package:ivy_pulse/presentation/reports/widgets/report_vehicle_card.dart';
import 'package:ivy_pulse/presentation/reports/widgets/report_vehicle_filters.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => ReportsPageState();
}

class ReportsPageState extends State<ReportsPage> {
  late final ReportsViewModel viewModel;

  final Set<String> expandedIds = {};

  ReportsTab selectedTab = ReportsTab.yours;
  ReportVehicleKey? selectedVehicle;
  late final NewPmcsController newPmcs;
  late final ReportBrowser browser;
  final searchController = TextEditingController();
  bool faultsOnly = false;
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ReportsViewModel>();
    browser = ReportBrowser(viewModel);
    newPmcs = NewPmcsController(
      resolveInspection: () => getIt.isRegistered<InspectionViewModel>() &&
              getIt.isRegistered<HomeViewModel>()
          ? getIt<InspectionViewModel>()
          : null,
      openInspection: () => getIt<HomeViewModel>().selectTab(0),
    );
    viewModel.reportToOpen.addListener(openRequestedReport);
    openRequestedReport();
  }

  @override
  void dispose() {
    viewModel.reportToOpen.removeListener(openRequestedReport);
    newPmcs.dispose();
    searchController.dispose();
    super.dispose();
  }

  void openRequestedReport() {
    final report = viewModel.reportToOpen.value;
    if (report == null) return;
    viewModel.reportToOpen.value = null;
    setState(() {
      selectedTab = report.isOutgoing ? ReportsTab.yours : ReportsTab.unit;
      selectedVehicle = (
        bumperNumber: report.bumperNumber.trim().toUpperCase(),
        uic: report.uic.trim().toUpperCase(),
      );
      expandedIds.add(report.entityId);
    });
    viewModel.markReportAsRead(report);
  }

  bool get hasVehicleFilters =>
      searchController.text.trim().isNotEmpty ||
      faultsOnly ||
      (selectedTab == ReportsTab.unit && unreadOnly);

  Map<ReportVehicleKey, List<PmcsReport>> filteredGroups(
    List<PmcsReport> reports,
  ) =>
      browser.filterGroups(
        reports,
        search: searchController.text,
        faultsOnly: faultsOnly,
        unreadOnly: selectedTab == ReportsTab.unit && unreadOnly,
      );

  void clearVehicleFilters() {
    setState(() {
      searchController.clear();
      faultsOnly = false;
      unreadOnly = false;
    });
  }

  Widget buildVehicleFilters() => ReportVehicleFilters(
        searchController: searchController,
        faultsOnly: faultsOnly,
        unreadOnly: unreadOnly,
        showUnread: selectedTab == ReportsTab.unit,
        hasVehicleFilters: hasVehicleFilters,
        onSearchChanged: (_) => setState(() {}),
        onClearSearch: () => setState(searchController.clear),
        onFaultsChanged: (value) => setState(() => faultsOnly = value),
        onUnreadChanged: (value) => setState(() => unreadOnly = value),
        onClearFilters: clearVehicleFilters,
      );

  void toggleExpanded(PmcsReport report) {
    viewModel.markReportAsRead(report);
    setState(() {
      if (!expandedIds.remove(report.entityId)) {
        expandedIds.add(report.entityId);
      }
    });
  }

  Future<void> confirmDelete(PmcsReport report) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete PMCS?',
      message: report.isOutgoing
          ? '${report.summary} will be withdrawn from Lattice and the mesh.'
          : '${report.summary} will be removed from this device only.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
      await viewModel.deleteReport(report);
    }
  }

  Future<void> startNewPmcs(PmcsReport report) => newPmcs.start(
        report,
        confirmContinue: (open) => showConfirmDialog(
          context,
          title: 'PMCS already in progress',
          message: '${open.displayTitle} · ${open.uic} has an open PMCS. '
              'Continue where you left off. Finish or discard that session '
              'before starting another.',
          confirmLabel: 'Continue PMCS',
          cancelLabel: 'Stay in reports',
        ),
      );

  Widget buildReportCard(PmcsReport report, {bool isLatest = false}) {
    final isExpanded = expandedIds.contains(report.entityId);
    final previousHistory =
        isExpanded ? browser.historyFor(report, previousOnly: true) : null;
    return PmcsReportCard(
      report: report,
      isLatest: isLatest,
      isExpanded: isExpanded,
      comparisons: [
        if (previousHistory != null)
          for (final phase in report.phases)
            previousHistory.compare(phase, report.faults),
      ],
      onToggleExpanded: () => toggleExpanded(report),
      onDelete:
          newPmcs.startingPmcsId != null ? null : () => confirmDelete(report),
    );
  }

  Widget buildVehicleCard(ReportVehicleKey vehicle, List<PmcsReport> reports) {
    final latest = reports.first;
    return ReportVehicleCard(
      key: ValueKey(vehicle),
      vehicle: vehicle,
      reports: reports,
      suggestionCount: browser.visibleSuggestionsFor(latest).length,
      isStarting: newPmcs.startingPmcsId == latest.entityId,
      canStart: newPmcs.startingPmcsId == null,
      onOpen: () => setState(() => selectedVehicle = vehicle),
      onNewPmcs: () => startNewPmcs(latest),
    );
  }

  List<PmcsReport> get vehicleHistory {
    final source = selectedTab == ReportsTab.yours
        ? viewModel.yourReports
        : viewModel.externalReports;
    return viewModel.groupByVehicle(source)[selectedVehicle] ?? const [];
  }

  List<Widget Function()> tabRows() {
    final rows = <Widget Function()>[];
    if (selectedTab == ReportsTab.queued) {
      final groups = viewModel.queuedByBumperNumber;
      if (groups.isEmpty) {
        return [
          () => ReportEmptyLine(
              message: 'Nothing waiting — every PMCS has been sent')
        ];
      }
      for (final entry in groups.entries) {
        rows.add(() => ReportBumperHeader(
            bumperNumber: entry.key, count: entry.value.length));
        for (final submission in entry.value) {
          rows.add(() => QueuedReportCard(submission: submission));
        }
      }
      return rows;
    }
    rows.add(buildVehicleFilters);
    final own = filteredGroups(selectedTab == ReportsTab.yours
        ? viewModel.yourReports
        : viewModel.unitReports);
    final others = selectedTab == ReportsTab.unit
        ? filteredGroups(viewModel.otherUnitReports)
        : <ReportVehicleKey, List<PmcsReport>>{};
    if (own.isEmpty && others.isEmpty) {
      rows.add(() => ReportEmptyLine(
          message: hasVehicleFilters
              ? 'No vehicles match your search or filters.'
              : selectedTab == ReportsTab.yours
                  ? 'No PMCS submitted from this device yet'
                  : 'No PMCS from other crews in your unit yet'));
    }
    for (final entry in own.entries) {
      rows.add(() => buildVehicleCard(entry.key, entry.value));
    }
    if (others.isNotEmpty) {
      rows.add(() => const Padding(
            padding: EdgeInsets.only(top: 22, bottom: 2),
            child: SectionLabel(text: 'OTHER UNITS'),
          ));
      for (final entry in others.entries) {
        rows.add(() => buildVehicleCard(entry.key, entry.value));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.suggestions, newPmcs]),
      builder: (context, _) {
        final vehicle = selectedVehicle;
        final history = vehicle == null ? const <PmcsReport>[] : vehicleHistory;
        final rows = vehicle == null
            ? tabRows()
            : history.isEmpty
                ? <Widget Function()>[
                    () => ReportEmptyLine(
                        message: 'No PMCS reports remain for this vehicle.')
                  ]
                : <Widget Function()>[
                    if (browser.suggestionsFor(history.first).isNotEmpty)
                      () => FaultSuggestions(
                            suggestions: browser.suggestionsFor(history.first),
                            controller: viewModel.suggestions,
                          ),
                    for (final (index, report) in history.indexed)
                      () => buildReportCard(report, isLatest: index == 0),
                  ];
        return Column(
          children: [
            ReportQueueBanner(queuedCount: viewModel.queuedCount),
            ReportTabs(
              selectedTab: selectedTab,
              unreadCount: viewModel.unreadCount,
              queuedCount: viewModel.queuedCount,
              onSelected: (tab) => setState(() {
                selectedTab = tab;
                selectedVehicle = null;
              }),
            ),
            if (vehicle != null)
              ReportHistoryHeader(
                vehicle: vehicle,
                count: history.length,
                onBack: () => setState(() => selectedVehicle = null),
              ),
            Expanded(
              child: RefreshIndicator(
                color: masterChiefGreen,
                backgroundColor: surface,
                onRefresh: viewModel.syncRemoteLatticeReports,
                child: ListView.builder(
                  key: PageStorageKey((selectedTab, vehicle)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => rows[index](),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
