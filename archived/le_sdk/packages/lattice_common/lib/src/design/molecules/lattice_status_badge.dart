import 'package:flutter/material.dart';

import '../tokens/lattice_spacing.dart';

/// Generic colored status pill badge.
///
/// Renders a small pill with [text] in [color] on a translucent background
/// of the same color. Theme-aware border radius.
///
/// For task-specific status badges with status group logic, see
/// `TaskStatusBadge` in `task_common.dart`.
class LatticeStatusBadge extends StatelessWidget {
  const LatticeStatusBadge({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LatticeSpacing.borderRadiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
