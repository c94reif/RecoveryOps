import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_page.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_prompt.dart';
import 'package:circle_x/presentation/common/widgets/pmcs_report_card.dart';
import 'package:circle_x/presentation/reports/controllers/report_browser.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';
import 'package:circle_x/presentation/reports/widgets/report_vehicle_filters.dart';

class MaintainerPage extends StatefulWidget {
  final VoidCallback onExit;

  const MaintainerPage({super.key, required this.onExit});

  @override
  State<MaintainerPage> createState() => MaintainerPageState();
}

class MaintainerPageState extends State<MaintainerPage> {
  late final ReportsViewModel viewModel = getIt<ReportsViewModel>();
  late final ReportBrowser browser = ReportBrowser(viewModel);
  final searchController = TextEditingController();
  final expandedIds = <String>{};
  bool refreshing = false;
  PmcsReport? reviewing;

  @override
  void initState() {
    super.initState();
    unawaited(refreshReports());
  }

  Future<void> refreshReports() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await viewModel.syncRemoteLatticeReports();
    } catch (error) {
      debugPrint('[CircleX] Maintainer report refresh failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not refresh reports. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearFilters() => setState(searchController.clear);

  List<PmcsReport> pendingReports(Iterable<PmcsReport> latest) {
    final submitted = <String, List<MaintainerReview>>{};
    for (final record in viewModel.reports) {
      final review = record.maintainerReview;
      if (review != null && review.signature.isVerified) {
        submitted.putIfAbsent(review.sourceReportId, () => []).add(review);
      }
    }
    return latest.where((report) {
      if (report.faults.isEmpty) return false;
      final keys =
          report.faults.map((fault) => (fault.phase, fault.itemId)).toSet();
      // A single signed batch must cover this exact PMCS. Delivery may still
      // be queued, and a "not verified" decision is still a completed review.
      return !(submitted[report.entityId] ?? []).any((review) =>
          review.faults.length == keys.length &&
          review.faults.every((fault) => keys.contains(fault.key)));
    }).toList();
  }

  Widget buildReport(PmcsReport report) {
    final expanded = expandedIds.contains(report.entityId);
    final previous =
        expanded ? browser.historyFor(report, previousOnly: true) : null;
    return Padding(
      key: ValueKey(report.entityId),
      padding: const EdgeInsets.only(bottom: 12),
      child: PmcsReportCard(
        report: report,
        isLatest: true,
        isExpanded: expanded,
        showDeleteAction: false,
        comparisons: [
          if (previous != null)
            for (final phase in report.phases)
              previous.compare(phase, report.faults),
        ],
        onToggleExpanded: () {
          setState(() {
            if (!expandedIds.remove(report.entityId)) {
              expandedIds.add(report.entityId);
            }
          });
          viewModel.markReportAsRead(report);
        },
        footer: MaintainerReviewPrompt(
          onReview: () => setState(() => reviewing = report),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = reviewing;
    if (active != null) {
      return MaintainerReviewPage(
        report: active,
        onExit: () => setState(() {
          reviewing = null;
        }),
      );
    }
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final latest = viewModel
            .groupByVehicle(viewModel.reports)
            .values
            .map((history) => history.first)
            .toList();
        final query = searchController.text.trim().toUpperCase();
        final pending = pendingReports(latest);
        final filtered = pending
            .where((report) => (query.isEmpty ||
                report.bumperNumber.toUpperCase().contains(query) ||
                report.uic.toUpperCase().contains(query)))
            .toList()
          ..sort((first, second) {
            final severity = (second.worstSeverity?.rank ?? 0)
                .compareTo(first.worstSeverity?.rank ?? 0);
            return severity != 0
                ? severity
                : second.timestamp.compareTo(first.timestamp);
          });
        final hasFilters = query.isNotEmpty;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Exit maintainer mode',
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        widget.onExit();
                      },
                      icon: const Icon(Icons.arrow_back),
                      constraints: const BoxConstraints(
                        minWidth: minTouchTarget,
                        minHeight: minTouchTarget,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Maintainer mode',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh reports',
                      onPressed: refreshing ? null : refreshReports,
                      icon: const Icon(Icons.refresh),
                      constraints: const BoxConstraints(
                        minWidth: minTouchTarget,
                        minHeight: minTouchTarget,
                      ),
                    ),
                  ],
                ),
              ),
              if (refreshing)
                const LinearProgressIndicator(
                  semanticsLabel: 'Checking for new reports',
                ),
              Expanded(
                child: RefreshIndicator(
                  color: masterChiefGreen,
                  backgroundColor: surface,
                  onRefresh: refreshReports,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      10,
                      0,
                      10,
                      12 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    itemCount: 2 + (filtered.isEmpty ? 1 : filtered.length),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${pending.length} ${pending.length == 1 ? 'vehicle' : 'vehicles'} awaiting review',
                                  style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 6),
                              const Text(
                                'Unreviewed faults, most severe first. '
                                'Submitted reviews are available in Reports.',
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        );
                      }
                      if (index == 1) {
                        return ReportVehicleFilters(
                          searchController: searchController,
                          faultsOnly: true,
                          showFaults: false,
                          unreadOnly: false,
                          showUnread: false,
                          hasVehicleFilters: hasFilters,
                          onSearchChanged: (_) => setState(() {}),
                          onClearSearch: () => setState(searchController.clear),
                          onFaultsChanged: (_) {},
                          onUnreadChanged: (_) {},
                          onClearFilters: clearFilters,
                        );
                      }
                      if (filtered.isEmpty) {
                        if (latest.isNotEmpty && pending.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Column(children: [
                              Icon(Icons.task_alt,
                                  color: serviceableGreen, size: 36),
                              SizedBox(height: 12),
                              Text('All caught up',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 8),
                              Text(
                                  'No vehicle faults are awaiting a signed maintainer review.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: textSecondary, height: 1.4)),
                            ]),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            refreshing && latest.isEmpty
                                ? 'Checking for new PMCS reports…'
                                : hasFilters
                                    ? 'No pending reviews match your search.'
                                    : 'No PMCS reports yet. Submitted and received '
                                        'reports will appear here.',
                            style: const TextStyle(color: textSecondary),
                          ),
                        );
                      }
                      return buildReport(filtered[index - 2]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
