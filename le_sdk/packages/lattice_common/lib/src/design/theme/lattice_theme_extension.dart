import 'package:flutter/material.dart';

import '../tokens/lattice_colors.dart';
import '../tokens/lattice_interaction.dart';
import '../tokens/lattice_typography.dart';

/// Theme extension that provides Lattice design tokens via [Theme.of(context)].
///
/// Access in widgets:
/// ```dart
/// final theme = Theme.of(context).extension<LatticeThemeExtension>()!;
/// Container(color: theme.colors.accent);
/// Text('Hello', style: theme.typography.body);
/// ```
///
/// Or use the [LatticeBuildContext] convenience extension:
/// ```dart
/// Container(color: context.lattice.colors.accent);
/// ```
class LatticeThemeExtension extends ThemeExtension<LatticeThemeExtension> {
  const LatticeThemeExtension({
    required this.colors,
    required this.typography,
    required this.interaction,
  });

  final LatticeColorScheme colors;
  final LatticeTypeScale typography;
  final LatticeInteractionTokens interaction;

  @override
  LatticeThemeExtension copyWith({
    LatticeColorScheme? colors,
    LatticeTypeScale? typography,
    LatticeInteractionTokens? interaction,
  }) {
    return LatticeThemeExtension(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      interaction: interaction ?? this.interaction,
    );
  }

  @override
  LatticeThemeExtension lerp(
    covariant LatticeThemeExtension? other,
    double t,
  ) {
    // Design tokens don't interpolate — snap to target.
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience extension for accessing Lattice design tokens from [BuildContext].
///
/// Usage:
/// ```dart
/// final colors = context.lattice.colors;
/// final typo = context.lattice.typography;
/// ```
extension LatticeBuildContext on BuildContext {
  LatticeThemeExtension get lattice =>
      Theme.of(this).extension<LatticeThemeExtension>()!;
}
