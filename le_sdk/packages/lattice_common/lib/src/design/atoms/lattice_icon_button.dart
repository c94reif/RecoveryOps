import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';
import 'lattice_interactive_wrapper.dart';

/// A Lattice-styled icon button with proper 48px touch targets and unified
/// interactive state feedback.
///
/// Uses [LatticeInteractiveWrapper] internally for hover, press, focus, and
/// disabled visual states. The icon color adapts to selected state.
///
/// ```dart
/// LatticeIconButton(
///   icon: Icons.layers,
///   onTap: () => toggleLayers(),
///   isSelected: layersVisible,
///   semanticLabel: 'Toggle layers',
/// )
/// ```
class LatticeIconButton extends StatelessWidget {
  /// Creates a Lattice icon button.
  const LatticeIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isSelected = false,
    this.size = 48,
    this.iconSize = 20,
    this.color,
    this.selectedColor,
    this.semanticLabel,
  });

  /// The icon to display.
  final IconData icon;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Whether the button responds to input.
  final bool enabled;

  /// Whether the button is in a selected/active state.
  final bool isSelected;

  /// Overall touch target size. Defaults to 48px (glove-friendly minimum).
  final double size;

  /// Icon glyph size. Defaults to 20px.
  final double iconSize;

  /// Icon color when not selected. Defaults to [LatticeColorScheme.inactive].
  final Color? color;

  /// Icon color when selected. Defaults to [LatticeColorScheme.iconActive].
  final Color? selectedColor;

  /// Accessibility label forwarded to [LatticeInteractiveWrapper].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final defaultColor = color ?? colors.inactive;
    final activeColor = selectedColor ?? colors.iconActive;
    final effectiveColor = isSelected ? activeColor : defaultColor;

    return LatticeInteractiveWrapper(
      onTap: onTap,
      enabled: enabled,
      isSelected: isSelected,
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}
