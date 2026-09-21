import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ReportsViewModel>();
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

  Widget buildFaultLine(PmcsFault fault) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReportCard(PmcsReport report) {
    final faults = sortedFaults(report);
    final isExpanded = expandedIds.contains(report.entityId);
    final visible =
        isExpanded ? faults : faults.take(collapsedFaultLimit).toList();
    final worst = report.worstSeverity;
    final accent = worst != null ? severityColor(worst) : serviceableGreen;

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
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => viewModel.viewReport(report),
                    icon: const Icon(Icons.place_outlined, size: 18),
                    tooltip: 'Show on map',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => confirmDelete(report),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
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
                for (final fault in visible) buildFaultLine(fault),
                if (!isExpanded && faults.length > collapsedFaultLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${faults.length - collapsedFaultLimit} more — '
                      'tap to expand',
                      style: TextStyle(color: masterChiefGreen, fontSize: 11),
                    ),
                  ),
              ],
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
          onSelectionChanged: (selection) =>
              setState(() => selectedTab = selection.first),
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
      child: Row(
        children: [
          SectionLabel(text: bumperNumber),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 PMCS' : '$count PMCS',
            style: const TextStyle(color: textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<Widget> buildGroupedReports(
    Map<String, List<PmcsReport>> groups,
    String emptyMessage,
  ) {
    if (groups.isEmpty) return [buildEmptyLine(emptyMessage)];
    return [
      for (final entry in groups.entries) ...[
        buildBumperHeader(entry.key, entry.value.length),
        for (final report in entry.value) buildReportCard(report),
      ],
    ];
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

  List<Widget> buildQueuedList() {
    final groups = viewModel.queuedByBumperNumber;
    if (groups.isEmpty) {
      return [buildEmptyLine('Nothing waiting — every PMCS has been sent')];
    }
    return [
      for (final entry in groups.entries) ...[
        buildBumperHeader(entry.key, entry.value.length),
        for (final submission in entry.value) buildQueuedCard(submission),
      ],
    ];
  }

  List<Widget> buildTabBody() {
    return switch (selectedTab) {
      ReportsTab.yours => buildGroupedReports(
          viewModel.groupByBumperNumber(viewModel.yourReports),
          'No PMCS submitted from this device yet',
        ),
      ReportsTab.unit => [
          ...buildGroupedReports(
            viewModel.groupByBumperNumber(viewModel.unitReports),
            'No PMCS from other crews in your unit yet',
          ),
          ...buildOtherUnits(),
        ],
      ReportsTab.queued => buildQueuedList(),
    };
  }

  /// PMCS from outside your UIC. They do not belong to this tab, but they are
  /// not dropped either — an attached vehicle can still be deadlined.
  List<Widget> buildOtherUnits() {
    final others = viewModel.groupByBumperNumber(viewModel.otherUnitReports);
    if (others.isEmpty) return const [];
    return [
      const Padding(
        padding: EdgeInsets.only(top: 22, bottom: 2),
        child: SectionLabel(text: 'OTHER UNITS'),
      ),
      for (final entry in others.entries) ...[
        buildBumperHeader(entry.key, entry.value.length),
        for (final report in entry.value) buildReportCard(report),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Column(
          children: [
            // The banner stays above the switch: a parked submission is worth
            // knowing about from whichever tab you are standing on.
            buildQueueBanner(),
            buildTabBar(),
            Expanded(
              child: RefreshIndicator(
                color: masterChiefGreen,
                backgroundColor: surface,
                onRefresh: viewModel.syncRemoteLatticeReports,
                child: ListView(
                  // Always scrollable so pull-to-refresh still reaches a
                  // maintainer holding an empty list after a comms blackout.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  children: buildTabBody(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
