import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_history.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/presentation/common/formatters/report_time.dart';
import 'package:circle_x/presentation/common/widgets/fault_history_widgets.dart';
import 'package:circle_x/presentation/common/widgets/fault_summary_line.dart';
import 'package:circle_x/presentation/common/widgets/fault_tally_bar.dart';

class PmcsReportCard extends StatelessWidget {
  final PmcsReport report;
  final bool isExpanded;
  final bool isLatest;
  final List<PhaseComparison> comparisons;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onDelete;
  final bool showDeleteAction;
  static const int collapsedFaultLimit = 3;

  const PmcsReportCard({
    super.key,
    required this.report,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.onDelete,
    this.showDeleteAction = true,
    this.isLatest = false,
    this.comparisons = const [],
  });

  List<PmcsFault> sortedFaults(PmcsReport report) {
    final faults = [...report.faults];
    faults.sort((firstFault, secondFault) =>
        secondFault.severity.rank.compareTo(firstFault.severity.rank));
    return faults;
  }

  @override
  Widget build(BuildContext context) {
    final faults = sortedFaults(report);
    final visible =
        isExpanded ? faults : faults.take(collapsedFaultLimit).toList();
    final worst = report.worstSeverity;
    final accent = worst != null ? severityColor(worst) : serviceableGreen;
    final hasNotes =
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
        onTap: onToggleExpanded,
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
                                '${formatRelativeAge(report.timestamp)}',
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
                  FaultSummaryLine(fault: fault, showNote: isExpanded),
              ],
              if (isExpanded) PmcsChanges(comparisons: comparisons),
              TextButton.icon(
                onPressed: onToggleExpanded,
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
                          : hasNotes
                              ? 'View operator notes'
                              : 'View changes',
                ),
              ),
              if (showDeleteAction) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onDelete,
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
            ],
          ),
        ),
      ),
    );
  }
}
