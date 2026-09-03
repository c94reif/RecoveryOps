import 'package:flutter/material.dart';

/// Utility extensions for converting [Color] to hex strings.
///
/// Use these when passing colors to non-Dart layers (JS map, HTML extensions)
/// that require hex string format.
extension LatticeColorHex on Color {
  /// Returns this color as a `#RRGGBB` hex string (e.g. `'#334EFF'`).
  ///
  /// Ignores alpha. Use for map markers, JS bridge calls, and HTML styling
  /// where the color must be a hex string.
  String toHex() {
    final r = (this.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (this.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (this.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
