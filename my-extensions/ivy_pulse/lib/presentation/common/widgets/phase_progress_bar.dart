import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

/// How far through a phase's TM checks the operator is.
class PhaseProgressBar extends StatelessWidget {
  final int done;
  final int total;

  /// Bar only, no counter — for headers where the count is already shown and
  /// vertical space is the scarce resource.
  final bool compact;

  const PhaseProgressBar({
    super.key,
    required this.done,
    required this.total,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && done >= total;
    final value = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();

    // Green only once every check in the phase is answered — a partially
    // walked phase must never read as a finished one.
    final tint =
        complete ? serviceableGreen : Theme.of(context).colorScheme.primary;

    if (compact) {
      return LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: surfaceLight,
        valueColor: AlwaysStoppedAnimation<Color>(tint),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$done / $total',
          style: TextStyle(
            color: tint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
