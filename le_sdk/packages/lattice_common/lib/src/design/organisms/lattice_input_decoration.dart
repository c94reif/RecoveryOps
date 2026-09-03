import 'package:flutter/material.dart';

import '../tokens/lattice_colors.dart';
import '../tokens/lattice_spacing.dart';

/// Shared [InputDecoration] factory matching the Lattice design system.
///
/// Replaces the 4+ private `_inputDecoration` helpers duplicated across
/// plugin form files. Accepts a [LatticeColorScheme] so it works both
/// with `context.lattice.colors` in widgets and with static presets in
/// contexts outside the widget tree.
///
/// Usage:
/// ```dart
/// TextField(
///   decoration: latticeInputDecoration(
///     context.lattice.colors,
///     hint: 'e.g. WARRIOR 6',
///     hasError: _nameError != null,
///   ),
/// )
/// ```
InputDecoration latticeInputDecoration(
  LatticeColorScheme colors, {
  String? hint,
  bool hasError = false,
}) {
  final borderColor = hasError ? colors.error : colors.borderActive;
  final focusBorderColor = hasError ? colors.error : colors.iconActive;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: focusBorderColor, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: colors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: colors.error, width: 1),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
      borderSide: BorderSide(color: colors.border, width: 1),
    ),
  );
}
