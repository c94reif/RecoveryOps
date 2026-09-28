import 'package:ivy_pulse/presentation/common/formatters/report_time.dart';
import 'package:ivy_pulse/presentation/common/widgets/pmcs_report_card.dart';
import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_history.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_history_widgets.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

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
  String? startingPmcsId;
  bool offeringContinuation = false;
  final searchController = TextEditingController();
  bool faultsOnly = false;
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ReportsViewModel>();
    viewModel.reportToOpen.addListener(openRequestedReport);
    openRequestedReport();
  }

  @override
  void dispose() {
    viewModel.reportToOpen.removeListener(openRequestedReport);
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
      List<PmcsReport> reports) {
    final query = searchController.text.trim().toUpperCase();
    return Map.fromEntries(
        viewModel.groupByVehicle(reports).entries.where((entry) {
      final vehicle = entry.key;
      return (query.isEmpty ||
              vehicle.bumperNumber.contains(query) ||
              vehicle.uic.contains(query)) &&
          (!faultsOnly ||
              entry.value.first.faults.isNotEmpty ||
              visibleSuggestionsFor(entry.value.first).isNotEmpty) &&
          (selectedTab != ReportsTab.unit ||
              !unreadOnly ||
              entry.value
                  .any((report) => !report.isOutgoing && !report.isRead));
    }));
  }

  void clearVehicleFilters() {
    setState(() {
      searchController.clear();
      faultsOnly = false;
      unreadOnly = false;
    });
  }

  Widget buildVehicleFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: 'Search bumper number or UIC',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(searchController.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilterChip(
              label: const Text('With faults'),
              selected: faultsOnly,
              onSelected: (value) => setState(() => faultsOnly = value)),
          if (selectedTab == ReportsTab.unit)
            FilterChip(
                label: const Text('Unread'),
                selected: unreadOnly,
                onSelected: (value) => setState(() => unreadOnly = value)),
          if (hasVehicleFilters)
            TextButton(
                onPressed: clearVehicleFilters,
                child: const Text('Clear filters')),
        ]),
      ]),
    );
  }

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

  Future<void> startNewPmcs(PmcsReport report) async {
    if (startingPmcsId != null || offeringContinuation) return;
    if (!getIt.isRegistered<InspectionViewModel>() ||
        !getIt.isRegistered<HomeViewModel>()) {
      return;
    }
    final inspection = getIt<InspectionViewModel>();
    if (inspection.isBusy) return;
    final accepted = inspection.prefillVehicle(
      bumperNumber: report.bumperNumber,
      uic: report.uic,
      vehicleType: report.vehicleType,
    );
    if (!accepted) {
      final open = inspection.session;
      if (open == null) return;
      offeringContinuation = true;
      try {
        final shouldContinue = await showConfirmDialog(
          context,
          title: 'PMCS already in progress',
          message: '${open.displayTitle} · ${open.uic} has an open PMCS. '
              'Continue where you left off. Finish or discard that session '
              'before starting another.',
          confirmLabel: 'Continue PMCS',
          cancelLabel: 'Stay in reports',
        );
        if (mounted &&
            shouldContinue &&
            inspection.session?.sessionId == open.sessionId) {
          getIt<HomeViewModel>().selectTab(0);
        }
      } finally {
        offeringContinuation = false;
      }
      return;
    }
    setState(() => startingPmcsId = report.entityId);
    try {
      final started = await inspection.beginSession(
        bumperNumber: report.bumperNumber,
        uic: report.uic,
      );
      if (!mounted || !started) return;
      getIt<HomeViewModel>().selectTab(0);
    } finally {
      if (mounted) setState(() => startingPmcsId = null);
    }
  }

  Widget buildQueueBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: viewModel.queuedCount,
      builder: (_, count, __) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: circleXGlow,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 16, color: circleXAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count submission${count == 1 ? '' : 's'} queued — '
                  'will send on reconnect',
                  style: const TextStyle(color: circleXAmber, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildReportCard(PmcsReport report, {bool isLatest = false}) {
    final isExpanded = expandedIds.contains(report.entityId);
    final previousHistory =
        isExpanded ? historyFor(report, previousOnly: true) : null;
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
      onDelete: startingPmcsId != null ? null : () => confirmDelete(report),
    );
  }

  Widget buildEmptyLine(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        message,
        style: const TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }

  Widget buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ReportsTab>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          segments: [
            for (final tab in ReportsTab.values)
              ButtonSegment(
                value: tab,
                label: buildTabLabel(tab),
              ),
          ],
          selected: {selectedTab},
          onSelectionChanged: (selection) => setState(() {
            selectedTab = selection.first;
            selectedVehicle = null;
          }),
        ),
      ),
    );
  }

  Widget buildTabLabel(ReportsTab tab) {
    final counter = switch (tab) {
      ReportsTab.yours => null,
      ReportsTab.unit => viewModel.unreadCount,
      ReportsTab.queued => viewModel.queuedCount,
    };
    final label = Text(tab.label, overflow: TextOverflow.ellipsis);
    if (counter == null) return label;
    return ValueListenableBuilder<int>(
      valueListenable: counter,
      builder: (_, count, child) {
        if (count == 0) return child!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: child!),
            const SizedBox(width: 4),
            Badge(label: Text('$count', style: const TextStyle(fontSize: 8))),
          ],
        );
      },
      child: label,
    );
  }

  Widget buildBumperHeader(String bumperNumber, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SectionLabel(text: bumperNumber),
          Text(
            count == 1 ? '1 PMCS' : '$count PMCS',
            style: const TextStyle(color: textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<Widget> buildGroupedReports(
    Map<ReportVehicleKey, List<PmcsReport>> groups,
    String emptyMessage,
  ) {
    if (groups.isEmpty) return [buildEmptyLine(emptyMessage)];
    return [
      for (final entry in groups.entries)
        buildVehicleCard(entry.key, entry.value),
    ];
  }

  Widget buildVehicleCard(ReportVehicleKey vehicle, List<PmcsReport> reports) {
    final latest = reports.first;
    final suggested = visibleSuggestionsFor(latest);
    final unread = reports
        .where((candidateReport) =>
            !candidateReport.isOutgoing && !candidateReport.isRead)
        .length;
    final worst = latest.worstSeverity;
    final accent = worst == null ? serviceableGreen : severityColor(worst);
    return Card(
      key: ValueKey(vehicle),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: unread > 0 ? accent : border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => selectedVehicle = vehicle),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    worst == null
                        ? Icons.check_circle_outline
                        : severityIcon(worst),
                    color: accent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle.bumperNumber} - ${latest.vehicleType.displayName}',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('UIC ${vehicle.uic}',
                            style: const TextStyle(
                                color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${reports.length} PMCS',
                      style: const TextStyle(color: textPrimary, fontSize: 12)),
                  Text('Latest ${formatRelativeAge(latest.timestamp)}',
                      style:
                          const TextStyle(color: textSecondary, fontSize: 12)),
                  if (unread > 0)
                    Text('$unread unread',
                        style:
                            const TextStyle(color: circleXAmber, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Latest report: ${latest.statusLabel}',
                  style: TextStyle(color: accent, fontSize: 12)),
              if (suggested.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '${suggested.length} earlier fault'
                        '${suggested.length == 1 ? '' : 's'} suggested for review',
                        style: const TextStyle(
                            color: circleXAmber, fontSize: 12))),
              if (!latest.tally.isEmpty) ...[
                const SizedBox(height: 6),
                FaultTallyBar(tally: latest.tally),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: buildNewPmcsButton(latest),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNewPmcsButton(PmcsReport report) {
    final isStarting = startingPmcsId == report.entityId;
    return Tooltip(
      message: 'New PMCS on this vehicle',
      child: OutlinedButton.icon(
        onPressed: startingPmcsId != null ? null : () => startNewPmcs(report),
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          disabledForegroundColor: textSecondary,
          backgroundColor: greenGlow,
          side: BorderSide(color: masterChiefGreen),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          minimumSize: const Size(0, minTouchTarget),
        ),
        icon: isStarting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textSecondary,
                ),
              )
            : const Icon(Icons.add_task, size: 18),
        label: Text(isStarting ? 'Starting PMCS…' : 'New PMCS'),
      ),
    );
  }

  List<PmcsReport> get vehicleHistory {
    final source = selectedTab == ReportsTab.yours
        ? viewModel.yourReports
        : viewModel.externalReports;
    return viewModel.groupByVehicle(source)[selectedVehicle] ?? const [];
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

  Widget buildHistoryHeader(ReportVehicleKey vehicle, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => selectedVehicle = null),
            tooltip: 'Back to vehicles',
            icon: const Icon(Icons.arrow_back),
            constraints: const BoxConstraints(
              minWidth: minTouchTarget,
              minHeight: minTouchTarget,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.bumperNumber,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('UIC ${vehicle.uic} · $count PMCS',
                    style: const TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQueuedCard(QueuedSubmission submission) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: circleXAmber, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: circleXAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    submission.summary,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatRelativeAge(submission.createdAt),
                  style: const TextStyle(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${submission.faultSummary} · waiting on '
              '${submission.transport.name}',
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget Function()> tabRows() {
    final rows = <Widget Function()>[];
    if (selectedTab == ReportsTab.queued) {
      final groups = viewModel.queuedByBumperNumber;
      if (groups.isEmpty) {
        return [
          () => buildEmptyLine('Nothing waiting — every PMCS has been sent')
        ];
      }
      for (final entry in groups.entries) {
        rows.add(() => buildBumperHeader(entry.key, entry.value.length));
        for (final submission in entry.value) {
          rows.add(() => buildQueuedCard(submission));
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
      rows.add(() => buildEmptyLine(hasVehicleFilters
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
      listenable: Listenable.merge([viewModel, viewModel.suggestions]),
      builder: (context, _) {
        final vehicle = selectedVehicle;
        final history = vehicle == null ? const <PmcsReport>[] : vehicleHistory;
        final rows = vehicle == null
            ? tabRows()
            : history.isEmpty
                ? <Widget Function()>[
                    () => buildEmptyLine(
                        'No PMCS reports remain for this vehicle.')
                  ]
                : <Widget Function()>[
                    if (suggestionsFor(history.first).isNotEmpty)
                      () => FaultSuggestions(
                            suggestions: suggestionsFor(history.first),
                            controller: viewModel.suggestions,
                          ),
                    for (final (index, report) in history.indexed)
                      () => buildReportCard(report, isLatest: index == 0),
                  ];
        return Column(
          children: [
            buildQueueBanner(),
            buildTabBar(),
            if (vehicle != null) buildHistoryHeader(vehicle, history.length),
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
