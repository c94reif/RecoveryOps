import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';

/// Orange section-divider header used to group related fields.
///
/// Theme-aware — background and text colors adapt to the active theme.
class LatticeSectionHeader extends StatelessWidget {
  const LatticeSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(LatticeSpacing.borderRadiusSmall),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
