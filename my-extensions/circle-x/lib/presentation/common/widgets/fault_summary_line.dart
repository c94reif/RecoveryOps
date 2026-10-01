import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/presentation/common/widgets/severity_badge.dart';

class FaultSummaryLine extends StatelessWidget {
  final PmcsFault fault;
  final bool showNote;

  const FaultSummaryLine(
      {super.key, required this.fault, this.showNote = false});

  @override
  Widget build(BuildContext context) {
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
}
