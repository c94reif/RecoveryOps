import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';

/// Speech-to-text dictation button. Shows red when actively listening.
///
/// Theme-aware — idle state colors adapt to the active theme.
class LatticeMicButton extends StatelessWidget {
  const LatticeMicButton({
    super.key,
    required this.listening,
    required this.onTap,
  });

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: LatticeSpacing.touchTarget,
          height: LatticeSpacing.touchTarget,
          decoration: BoxDecoration(
            color: listening ? const Color(0xFF5C1A1A) : colors.surface,
            border: Border.all(
              color: listening ? colors.error : colors.borderActive,
            ),
            borderRadius:
                BorderRadius.circular(LatticeSpacing.borderRadius),
          ),
          child: Icon(
            Icons.mic,
            size: 20,
            color: listening ? colors.error : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
