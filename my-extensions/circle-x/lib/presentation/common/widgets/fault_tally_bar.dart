import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/presentation/common/widgets/severity_badge.dart';

class FaultTallyBar extends StatelessWidget {
  final FaultTally tally;

  const FaultTallyBar({super.key, required this.tally});

  @override
  Widget build(BuildContext context) {
    if (tally.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${tally.total} ${tally.total == 1 ? 'FAULT' : 'FAULTS'}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textSecondary,
          ),
        ),
        for (final severity in FaultSeverity.values)
          if (tally.countOf(severity) > 0)
            SeverityBadge(
              severity: severity,
              count: tally.countOf(severity),
            ),
      ],
    );
  }
}
