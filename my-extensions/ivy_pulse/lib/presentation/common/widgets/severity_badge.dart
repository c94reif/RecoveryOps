import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';

/// Compact pill for a single fault symbol, optionally with how many of that
/// symbol were found ('RED X: 3').
class SeverityBadge extends StatelessWidget {
  final FaultSeverity severity;
  final int? count;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final tint = severityColor(severity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: severityGlow(severity),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tint, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glyph and label repeat what the colour says, so a red-green
            // colour blind operator still reads the symbol correctly.
            Icon(severityIcon(severity), color: tint, size: 14),
            const SizedBox(width: 4),
            Text(
              count == null ? severity.label : '${severity.label}: $count',
              style: TextStyle(
                color: tint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
