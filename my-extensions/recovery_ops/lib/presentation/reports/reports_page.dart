import 'package:flutter/material.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/app_theme.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final ReportsViewModel viewModel;
  late final NavigationViewModel navigationViewModel;
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ReportsViewModel>();
    navigationViewModel = getIt<NavigationViewModel>();
    navigationViewModel.refreshLocation();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void showDetail(RecoveryReport report) {
    viewModel.markReportAsRead(report);
    viewModel.viewReport(report);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.bumperNumber} — ${report.recoveryType}',
                style: TextStyle(
                  color: masterChiefGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              row(report.isOutgoing ? 'Direction' : 'From',
                  report.isOutgoing ? 'Sent by you' : report.fromCallsign),
              row('Issue', report.issue),
              row('Location',
                  '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}'),
              row('Time', formatTime(report.timestamp)),
              if (viewModel.distanceTo(report) != null)
                row('Distance', viewModel.distanceTo(report)!),
              if (!report.isOutgoing && navigationViewModel.hasLocation) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      viewModel.navigateTo(report);
                    },
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: masterChiefGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.day}/${local.month}/${local.year}';
  }

  Widget buildReportCard(RecoveryReport report) {
    const orange = Color(0xFFFF8C00);
    const navBlue = Color(0xFF4A90D9);
    const unreadPurple = Color(0xFF7B1FA2);
    final isNavigating = !report.isOutgoing &&
        navigationViewModel.navigatingEntityId != null &&
        navigationViewModel.navigatingEntityId == report.entityId;
    final accentColor = isNavigating
        ? navBlue
        : (report.hasGeometry ? orange : masterChiefGreen);
    final isTowBar = report.recoveryType == 'Tow Bar';

    return Dismissible(
      key: ValueKey(report.id ?? report.hashCode),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => viewModel.deleteReport(report),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: report.isRead ? null : unreadPurple.withAlpha(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isNavigating
              ? const BorderSide(color: navBlue, width: 1.5)
              : report.hasGeometry
                  ? const BorderSide(color: orange, width: 1.2)
                  : !report.isRead
                      ? const BorderSide(color: unreadPurple, width: 1.2)
                      : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDetail(report),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isTowBar ? Icons.change_history : Icons.local_shipping,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${report.bumperNumber} — ${report.recoveryType}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: report.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (report.hasGeometry)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.route,
                                      color: orange, size: 14),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${report.isOutgoing ? 'Sent' : 'From ${report.fromCallsign}'} · ${formatTime(report.timestamp)}'
                            '${viewModel.distanceTo(report) != null ? ' · ${viewModel.distanceTo(report)}' : ''}',
                            style: TextStyle(
                              color: report.isRead
                                  ? const Color(0xFFA0A8B0)
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: report.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!report.isOutgoing &&
                        navigationViewModel.hasLocation) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () {
                          viewModel.markReportAsRead(report);
                          viewModel.navigateTo(report);
                          if (!report.isOutgoing) {
                            getIt<HomeViewModel>().selectTab(2);
                          }
                        },
                        icon: Icon(
                            navigationViewModel.navigatingEntityId != null &&
                                    navigationViewModel.navigatingEntityId ==
                                        report.entityId
                                ? Icons.navigation
                                : Icons.navigation_outlined,
                            size: 18,
                            color: accentColor),
                        tooltip: 'Navigate',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
              if (report.isOutgoing &&
                  viewModel.navigatorProgress(report) != null) ...[
                Padding(
                  padding:
                      const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_circle,
                              size: 14, color: masterChiefGreen),
                          const SizedBox(width: 4),
                          Text(
                            'Responder en route — ${viewModel.navigatorDistanceRemaining(report)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: viewModel.navigatorProgress(report),
                          backgroundColor: Colors.white12,
                          color: masterChiefGreen,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildReportList(List<RecoveryReport> reports, String emptyMessage) {
    if (reports.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: masterChiefGreen, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: reports.length,
      itemBuilder: (context, i) => buildReportCard(reports[i]),
    );
  }

  Widget buildExternalReportsList() {
    final grouped = viewModel.groupedExternalReports;
    final unread = viewModel.unreadPerBracket;

    final nonEmptyBrackets =
        DistanceBracket.values.where((b) => grouped[b]!.isNotEmpty).toList();

    if (nonEmptyBrackets.isEmpty) {
      return Center(
        child: Text(
          'No external reports yet',
          style: TextStyle(color: masterChiefGreen, fontSize: 16),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      children: [
        for (final bracket in nonEmptyBrackets)
          buildBracketAccordion(
            bracket,
            grouped[bracket]!,
            unread[bracket] ?? 0,
          ),
      ],
    );
  }

  Widget buildBracketAccordion(
    DistanceBracket bracket,
    List<RecoveryReport> reports,
    int unreadCount,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: unreadCount > 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Row(
          children: [
            Text(
              '${bracket.label} (${reports.length})',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 8),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => viewModel.markBracketAsRead(bracket),
                child: const Icon(
                  Icons.done_all,
                  size: 16,
                  color: Colors.white60,
                ),
              ),
            ],
          ],
        ),
        iconColor: masterChiefGreen,
        collapsedIconColor: Colors.white60,
        children: reports.map((r) => buildReportCard(r)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, navigationViewModel]),
      builder: (context, _) {
        return Column(
          children: [
            TabBar(
              controller: tabController,
              labelColor: masterChiefGreen,
              unselectedLabelColor: Colors.white60,
              indicatorColor: masterChiefGreen,
              tabs: const [
                Tab(text: 'External Reports'),
                Tab(text: 'Your Reports'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  buildExternalReportsList(),
                  buildReportList(viewModel.yourReports, 'No reports sent yet'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
