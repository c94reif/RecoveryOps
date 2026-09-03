// GENERATED — do not edit by hand.
// Source: design-tokens/tokens.json
// Run: dart run scripts/generate-tokens.dart

import 'package:flutter/material.dart';

/// Lattice interaction tokens — overlays, focus rings, disabled opacity.
///
/// Generated from design-tokens/tokens.json.
class LatticeInteractionTokens {
  const LatticeInteractionTokens({
    required this.hoverTint,
    required this.pressedTint,
    required this.focusRingColor,
    required this.selectedTintOpacity,
  });

  final double hoverTint;

  final double pressedTint;

  final Color focusRingColor;

  final double selectedTintOpacity;

  static const double disabledOpacity = 0.38;

  static const double focusRingWidth = 2.0;

  /// Default dark theme interaction tokens.
  static const dark = LatticeInteractionTokens(
    hoverTint: 0.08,
    pressedTint: 0.12,
    focusRingColor: Color(0xFF5569ED),
    selectedTintOpacity: 0.15,
  );

  /// Light theme interaction tokens.
  static const light = LatticeInteractionTokens(
    hoverTint: 0.06,
    pressedTint: 0.1,
    focusRingColor: Color(0xFF334EFF),
    selectedTintOpacity: 0.12,
  );

  /// High-contrast interaction tokens.
  static const highContrast = LatticeInteractionTokens(
    hoverTint: 0.12,
    pressedTint: 0.18,
    focusRingColor: Color(0xFFC3FF00),
    selectedTintOpacity: 0.2,
  );

}
