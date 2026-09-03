import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_colors.dart';
import '../tokens/lattice_spacing.dart';

/// Visual style variants for [LatticeButton].
enum LatticeButtonVariant { primary, secondary, warning, danger, success }

/// Unified Lattice button atom.
///
/// Replaces the previous per-variant button classes ([LatticePrimaryButton],
/// [LatticeSecondaryButton], etc.) with a single widget driven by
/// [LatticeButtonVariant].
///
/// ```dart
/// LatticeButton(
///   label: 'Confirm',
///   variant: LatticeButtonVariant.primary,
///   onPressed: () => submit(),
/// )
/// ```
///
/// For one-off colors that don't map to a variant, use [LatticeButton.custom].
class LatticeButton extends StatelessWidget {
  const LatticeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LatticeButtonVariant.primary,
    this.enabled = true,
    this.icon,
    this.isCompact = false,
    this.isFullWidth = true,
    this.semanticLabel,
  })  : _customBg = null,
        _customFg = null;

  /// Construct a button with explicit background/foreground colors instead of
  /// resolving from a [LatticeButtonVariant].
  const LatticeButton.custom({
    super.key,
    required this.label,
    required this.onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    this.enabled = true,
    this.icon,
    this.isCompact = false,
    this.isFullWidth = true,
    this.semanticLabel,
  })  : variant = LatticeButtonVariant.primary,
        _customBg = backgroundColor,
        _customFg = foregroundColor;

  final String label;
  final VoidCallback? onPressed;
  final LatticeButtonVariant variant;
  final bool enabled;
  final IconData? icon;
  final bool isCompact;
  final bool isFullWidth;
  final String? semanticLabel;

  final Color? _customBg;
  final Color? _customFg;

  // ---------------------------------------------------------------------------
  // Color resolution
  // ---------------------------------------------------------------------------

  /// Foreground colors per variant.
  ///
  /// TODO(design-system): Once LatticeColorScheme gains onAccent / onWarning /
  /// onError / onSuccess fields, resolve from the color scheme instead of
  /// hardcoding.
  Color _foreground(LatticeColorScheme colors) {
    if (_customFg != null) return _customFg!;
    switch (variant) {
      case LatticeButtonVariant.primary:
      case LatticeButtonVariant.danger:
      case LatticeButtonVariant.success:
        return Colors.white;
      case LatticeButtonVariant.warning:
        return const Color(0xFF1A1A1A);
      case LatticeButtonVariant.secondary:
        return colors.textSecondary;
    }
  }

  Color _background(LatticeColorScheme colors) {
    if (_customBg != null) return _customBg!;
    switch (variant) {
      case LatticeButtonVariant.primary:
        return colors.accent;
      case LatticeButtonVariant.secondary:
        return colors.surface;
      case LatticeButtonVariant.warning:
        return colors.statusPending;
      case LatticeButtonVariant.danger:
        return colors.error;
      case LatticeButtonVariant.success:
        return colors.success;
    }
  }

  BorderSide? _border(LatticeColorScheme colors) {
    if (_customBg != null) return null; // custom colors — no border
    if (variant == LatticeButtonVariant.secondary) {
      return BorderSide(color: colors.borderActive);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final bg = _background(colors);
    final fg = _foreground(colors);
    final border = _border(colors);

    final height = isCompact
        ? LatticeSpacing.touchTargetCompact
        : LatticeSpacing.touchTarget;

    final child = icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          );

    Widget button = SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
            side: border ?? BorderSide.none,
          ),
          padding: isCompact
              ? const EdgeInsets.symmetric(horizontal: 12)
              : EdgeInsets.zero,
        ),
        child: child,
      ),
    );

    if (!enabled) {
      button = Opacity(opacity: 0.38, child: button);
    }

    if (semanticLabel != null) {
      button = Semantics(label: semanticLabel, child: button);
    }

    return button;
  }
}

// =============================================================================
// Deprecated wrapper classes — migrate to LatticeButton with a variant.
// =============================================================================

/// Use [LatticeButton] with [LatticeButtonVariant.primary] instead.
@Deprecated('Use LatticeButton(variant: LatticeButtonVariant.primary)')
class LatticePrimaryButton extends StatelessWidget {
  const LatticePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LatticeButton(
      label: label,
      onPressed: onPressed,
      variant: LatticeButtonVariant.primary,
      enabled: enabled,
    );
  }
}

/// Use [LatticeButton] with [LatticeButtonVariant.secondary] instead.
@Deprecated('Use LatticeButton(variant: LatticeButtonVariant.secondary)')
class LatticeSecondaryButton extends StatelessWidget {
  const LatticeSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LatticeButton(
      label: label,
      onPressed: onPressed,
      variant: LatticeButtonVariant.secondary,
      enabled: enabled,
    );
  }
}

/// Use [LatticeButton] with [LatticeButtonVariant.warning] instead.
@Deprecated('Use LatticeButton(variant: LatticeButtonVariant.warning)')
class LatticeWarningButton extends StatelessWidget {
  const LatticeWarningButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LatticeButton(
      label: label,
      onPressed: onPressed,
      variant: LatticeButtonVariant.warning,
      enabled: enabled,
    );
  }
}

/// Use [LatticeButton] with [LatticeButtonVariant.danger] instead.
@Deprecated('Use LatticeButton(variant: LatticeButtonVariant.danger)')
class LatticeDangerButton extends StatelessWidget {
  const LatticeDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LatticeButton(
      label: label,
      onPressed: onPressed,
      variant: LatticeButtonVariant.danger,
      enabled: enabled,
    );
  }
}

/// Use [LatticeButton] with a variant or [LatticeButton.custom] instead.
@Deprecated('Use LatticeButton with a variant or LatticeButton.custom')
class LatticeCompactButton extends StatelessWidget {
  const LatticeCompactButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return LatticeButton.custom(
      label: label,
      onPressed: onPressed,
      backgroundColor: color,
      foregroundColor: Colors.white,
      icon: icon,
      isCompact: true,
      isFullWidth: false,
    );
  }
}
