import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';

/// Fault counts for a session, phase or report, worst symbol first.
class FaultTallyBar extends StatelessWidget {
  final FaultTally tally;

  const FaultTallyBar({super.key, required this.tally});

  @override
  Widget build(BuildContext context) {
    // A clean vehicle gets no badge row at all — absence of faults is the
    // default state and should not compete with the checks for space.
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
