import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';

class PhaseProgressBar extends StatelessWidget {
  final int done;
  final int total;

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
