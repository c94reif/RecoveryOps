import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';

class InspectionFaultCard extends StatelessWidget {
  final PmcsFault fault;
  final VoidCallback? onReview;

  const InspectionFaultCard({super.key, required this.fault, this.onReview});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(fault.severity);
    final note = fault.note;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onReview,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    fault.itemId,
                    style: TextStyle(
                      color: masterChiefGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  SeverityBadge(severity: fault.severity),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                fault.subcategory,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${fault.category} · ${fault.phase.shortLabel}',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                fault.condition,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      color: textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              const Row(children: [
                Text('Review check',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: textSecondary, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
