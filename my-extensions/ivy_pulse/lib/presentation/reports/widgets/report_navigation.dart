import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

class ReportTabs extends StatelessWidget {
  final ReportsTab selectedTab;
  final ValueListenable<int> unreadCount;
  final ValueListenable<int> queuedCount;
  final ValueChanged<ReportsTab> onSelected;

  const ReportTabs({
    super.key,
    required this.selectedTab,
    required this.unreadCount,
    required this.queuedCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
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
          onSelectionChanged: (selection) => onSelected(selection.first),
        ),
      ),
    );
  }

  Widget buildTabLabel(ReportsTab tab) {
    final counter = switch (tab) {
      ReportsTab.yours => null,
      ReportsTab.unit => unreadCount,
      ReportsTab.queued => queuedCount,
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
}

class ReportHistoryHeader extends StatelessWidget {
  final ReportVehicleKey vehicle;
  final int count;
  final VoidCallback onBack;

  const ReportHistoryHeader({
    super.key,
    required this.vehicle,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
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
}
