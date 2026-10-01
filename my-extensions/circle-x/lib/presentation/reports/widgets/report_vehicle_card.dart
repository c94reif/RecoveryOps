import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';
import 'package:circle_x/presentation/common/formatters/report_time.dart';
import 'package:circle_x/presentation/common/widgets/fault_tally_bar.dart';

class ReportVehicleCard extends StatelessWidget {
  final ReportVehicleKey vehicle;
  final List<PmcsReport> reports;
  final int suggestionCount;
  final bool isStarting;
  final bool canStart;
  final VoidCallback onOpen;
  final VoidCallback onNewPmcs;

  const ReportVehicleCard({
    super.key,
    required this.vehicle,
    required this.reports,
    required this.suggestionCount,
    required this.isStarting,
    required this.canStart,
    required this.onOpen,
    required this.onNewPmcs,
  });

  @override
  Widget build(BuildContext context) {
    final latest = reports.first;
    final unread = reports
        .where((candidateReport) =>
            !candidateReport.isOutgoing && !candidateReport.isRead)
        .length;
    final worst = latest.worstSeverity;
    final accent = worst == null ? serviceableGreen : severityColor(worst);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: unread > 0 ? accent : border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
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
              if (suggestionCount > 0)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '$suggestionCount earlier fault'
                        '${suggestionCount == 1 ? '' : 's'} suggested for review',
                        style: const TextStyle(
                            color: circleXAmber, fontSize: 12))),
              if (!latest.tally.isEmpty) ...[
                const SizedBox(height: 6),
                FaultTallyBar(tally: latest.tally),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: buildNewPmcsButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNewPmcsButton() {
    return Tooltip(
      message: 'New PMCS on this vehicle',
      child: OutlinedButton.icon(
        onPressed: canStart ? onNewPmcs : null,
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
}
