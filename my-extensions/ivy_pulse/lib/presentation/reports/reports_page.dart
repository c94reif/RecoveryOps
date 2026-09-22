import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

/// How many faults a collapsed card shows before the operator has to expand.
const int collapsedFaultLimit = 3;

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => ReportsPageState();
}

class ReportsPageState extends State<ReportsPage> {
  late final ReportsViewModel viewModel;

  /// Entity ids of cards showing their full fault list.
  final Set<String> expandedIds = {};

  /// Which of the three views is showing. Page state rather than view-model
  /// state: it is where the maintainer is looking, not anything about the
  /// PMCS themselves.
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
          (!faultsOnly || entry.value.first.faults.isNotEmpty) &&
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

  /// Start a fresh session using the report's vehicle details, then open the
  /// PMCS tab at phase selection.
  ///
  /// Resolved at tap time rather than in [initState] so a reports screen can
  /// be built without an inspection flow behind it, as the widget tests do.
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

  /// Worst first — the maintainer reads the deadlining faults, not the order
  /// the operator happened to walk the vehicle in.
  List<PmcsFault> sortedFaults(PmcsReport report) {
    final faults = [...report.faults];
    faults.sort((a, b) => b.severity.rank.compareTo(a.severity.rank));
    return faults;
  }

  String relativeAge(DateTime timestamp) {
    final elapsed = DateTime.now().difference(timestamp.toLocal());
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
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

  Widget buildFaultLine(PmcsFault fault, {required bool showNote}) {
    final note = fault.note?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SeverityBadge(severity: fault.severity),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fault.subcategory} — ${fault.condition}',
                  style: const TextStyle(color: textPrimary, fontSize: 12),
                ),
                Text(
                  '${fault.phase.shortLabel} · ${fault.itemId}',
                  style: const TextStyle(color: textSecondary, fontSize: 10),
                ),
                if (showNote && note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Operator note: $note',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReportCard(PmcsReport report, {bool isLatest = false}) {
    final faults = sortedFaults(report);
    final isExpanded = expandedIds.contains(report.entityId);
    final visible =
        isExpanded ? faults : faults.take(collapsedFaultLimit).toList();
    final worst = report.worstSeverity;
    final accent = worst != null ? severityColor(worst) : serviceableGreen;
    final hasDetails = faults.length > collapsedFaultLimit ||
        faults.any((fault) => fault.note?.trim().isNotEmpty ?? false);
    final localTime = report.timestamp.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localTime),
      alwaysUse24HourFormat: true,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: report.isRead ? border : accent,
          width: report.isRead ? 1 : 1.4,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => toggleExpanded(report),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isLatest ? 'LATEST · ' : ''}$date · $time',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: worst != null ? severityGlow(worst) : greenGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      worst != null
                          ? severityIcon(worst)
                          : Icons.check_circle_outline,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.summary,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: report.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Who signed it is the first thing a maintainer
                            // needs to trust, so an unsigned report says so
                            // right next to the name rather than deeper in
                            // the card where it could be missed.
                            if (!report.isSignatureVerified) ...[
                              const Icon(
                                Icons.gpp_maybe_outlined,
                                color: circleXAmber,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                '${report.operator} · ${report.uic} · '
                                '${relativeAge(report.timestamp)}',
                                style: TextStyle(
                                  color: report.isSignatureVerified
                                      ? textSecondary
                                      : circleXAmber,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // The DoD ID is what ties the name to a person in
                        // DEERS, so a maintainer chasing a signature has it
                        // on the card. A typed one is printed too — it is
                        // still the number to chase — but says so, because
                        // it was never checked against a card.
                        if (report.signature?.dodId case final dodId?) ...[
                          const SizedBox(height: 2),
                          Text(
                            report.isSignatureVerified
                                ? 'DoD ID $dodId'
                                : 'DoD ID $dodId · typed, not scanned',
                            style: TextStyle(
                              color: report.isSignatureVerified
                                  ? textSecondary
                                  : circleXAmber,
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FaultTallyBar(tally: report.tally),
              if (faults.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No faults — fully serviceable',
                    style: TextStyle(color: serviceableGreen, fontSize: 12),
                  ),
                )
              else ...[
                for (final fault in visible)
                  buildFaultLine(fault, showNote: isExpanded),
              ],
              if (hasDetails)
                TextButton.icon(
                  onPressed: () => toggleExpanded(report),
                  style: TextButton.styleFrom(
                    foregroundColor: serviceableGreen,
                    minimumSize: const Size(0, minTouchTarget),
                  ),
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    isExpanded
                        ? 'Show less'
                        : faults.length > collapsedFaultLimit
                            ? '+${faults.length - collapsedFaultLimit} more — '
                                'tap to expand'
                            : 'View operator notes',
                  ),
                ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'New PMCS on this vehicle',
                      child: OutlinedButton.icon(
                        onPressed: startingPmcsId != null
                            ? null
                            : () => startNewPmcs(report),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          disabledForegroundColor: textSecondary,
                          backgroundColor: greenGlow,
                          side: BorderSide(color: masterChiefGreen),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          minimumSize: const Size(0, minTouchTarget),
                        ),
                        icon: startingPmcsId == report.entityId
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: textSecondary,
                                ),
                              )
                            : const Icon(Icons.add_task, size: 18),
                        label: Text(startingPmcsId == report.entityId
                            ? 'Starting PMCS…'
                            : 'New PMCS'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: startingPmcsId != null
                        ? null
                        : () => confirmDelete(report),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(
                      minWidth: minTouchTarget,
                      minHeight: minTouchTarget,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  /// Segmented switch across the three views, with the unread and queued
  /// counts on the tabs they belong to so a maintainer sees the work without
  /// opening each one.
  Widget buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ReportsTab>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            // Three segments on a panel this narrow; the default padding
            // pushes the labels into ellipses.
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

  /// One vehicle's worth of PMCS, however many that is.
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
    final unread = reports.where((r) => !r.isOutgoing && !r.isRead).length;
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
                  Text('Latest ${relativeAge(latest.timestamp)}',
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
              if (!latest.tally.isEmpty) ...[
                const SizedBox(height: 6),
                FaultTallyBar(tally: latest.tally),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PmcsReport> get vehicleHistory {
    final source = selectedTab == ReportsTab.yours
        ? viewModel.yourReports
        : viewModel.externalReports;
    return viewModel.groupByVehicle(source)[selectedVehicle] ?? const [];
  }

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

  /// A parked submission. Deliberately not a report card: this one has not
  /// reached anybody, and the only facts we hold are what was encoded at
  /// submit time.
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
                  relativeAge(submission.createdAt),
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
      listenable: viewModel,
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
                    for (final (index, report) in history.indexed)
                      () => buildReportCard(report, isLatest: index == 0),
                  ];
        return Column(
          children: [
            // The banner stays above the switch: a parked submission is worth
            // knowing about from whichever tab you are standing on.
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
                  // Always scrollable so pull-to-refresh still reaches a
                  // maintainer holding an empty list after a comms blackout.
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
