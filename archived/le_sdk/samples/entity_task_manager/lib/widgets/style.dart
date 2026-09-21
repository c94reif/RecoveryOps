import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

/// Shared style helpers following the Lattice design system.
///
/// Uses design tokens from [LatticeColorScheme] via [BuildContext] where
/// possible. Static constants provided as fallback for contexts without
/// a [BuildContext].
abstract final class LatticeStyle {
  static const _d = LatticeColorScheme.dark;
  static Color get background => _d.background;
  static Color get surface => _d.surface;
  static Color get border => _d.borderActive;
  static Color get borderLight => _d.border;
  static Color get accent => _d.accent;
  static Color get textPrimary => _d.textPrimary;
  static Color get textSecondary => _d.textSecondary;
  static Color get textMuted => _d.inactive;
  static Color get sectionLabel => _d.textLabel;
  static Color get success => _d.success;
  static Color get error => _d.error;

  static InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _d.textMuted, fontSize: 13),
      filled: true,
      fillColor: surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accent, width: 1),
      ),
    );
  }

  /// Primary button style — uses theme accent with proper foreground.
  static ButtonStyle primaryButtonFrom(LatticeColorScheme colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  /// Secondary button style — outlined with surface background.
  static ButtonStyle secondaryButtonFrom(LatticeColorScheme colors) {
    return ElevatedButton.styleFrom(
      backgroundColor: colors.surface,
      foregroundColor: colors.textSecondary,
      side: BorderSide(color: colors.borderActive),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // Deprecated — use primaryButtonFrom/secondaryButtonFrom with theme colors.
  static ButtonStyle primaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF334EFF),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  static ButtonStyle secondaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: textSecondary,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
