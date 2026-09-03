// GENERATED — do not edit by hand.
// Source: design-tokens/tokens.json
// Run: dart run scripts/generate-tokens.dart

import 'package:flutter/material.dart';

import 'lattice_colors.dart';

/// Lattice type scale — instance-based for runtime theme switching.
///
/// Generated from design-tokens/tokens.json.
class LatticeTypeScale {
  LatticeTypeScale(LatticeColorScheme colors)
      : 
        sectionLabel = TextStyle(
          color: colors.textLabel,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        body = TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium = TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        small = TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        buttonLabel = TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        title = TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleLarge = TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )
;

  /// Uppercase section headers, field labels.
  final TextStyle sectionLabel;

  /// Standard body text.
  final TextStyle body;

  /// Emphasized body text.
  final TextStyle bodyMedium;

  /// Badges, timestamps, metadata.
  final TextStyle small;

  /// Button text.
  final TextStyle buttonLabel;

  /// Panel headers, card titles.
  final TextStyle title;

  /// Screen-level titles.
  final TextStyle titleLarge;

}
