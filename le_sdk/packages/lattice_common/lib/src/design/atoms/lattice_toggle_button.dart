import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_colors.dart';
import '../tokens/lattice_spacing.dart';

/// Semantic variant for [LatticeToggleButton] color resolution.
enum LatticeToggleVariant { accent, hostile, friendly, warning }

/// Parameterized colored selection button with semantic variant support.
///
/// Selected state uses the variant's accent color for border and tinted
/// background. Unselected state uses theme surface/border/inactive colors.
///
/// Use [LatticeToggleVariant] to select a color scheme:
/// - [accent] — default blue accent
/// - [hostile] — red entity hostile
/// - [friendly] — blue entity friendly
/// - [warning] — amber status pending
class LatticeToggleButton extends StatelessWidget {
  const LatticeToggleButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.variant = LatticeToggleVariant.accent,
    this.enabled = true,
    this.height = LatticeSpacing.touchTarget,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final LatticeToggleVariant variant;
  final bool enabled;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final (variantColor, variantTextColor) = _resolveVariant(colors);

    final bg = isSelected
        ? Color.lerp(colors.surface, variantColor, 0.15)!
        : colors.surface;
    final border = isSelected ? variantTextColor : colors.borderActive;
    final text = isSelected ? variantTextColor : colors.inactive;

    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: text),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns (variantColor, selectedTextColor) for the given variant.
  (Color, Color) _resolveVariant(LatticeColorScheme colors) {
    switch (variant) {
      case LatticeToggleVariant.accent:
        return (colors.accent, colors.iconActive);
      case LatticeToggleVariant.hostile:
        return (colors.entityHostile, colors.entityHostile);
      case LatticeToggleVariant.friendly:
        return (colors.entityFriendly, colors.entityFriendly);
      case LatticeToggleVariant.warning:
        return (colors.statusPending, colors.statusPending);
    }
  }
}
