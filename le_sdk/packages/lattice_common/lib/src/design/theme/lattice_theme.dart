import 'package:flutter/material.dart';

import '../tokens/lattice_colors.dart';
import '../tokens/lattice_interaction.dart';
import '../tokens/lattice_spacing.dart';
import '../tokens/lattice_typography.dart';
import 'lattice_theme_extension.dart';

/// Factory for fully configured [ThemeData] instances.
///
/// Usage in `MaterialApp`:
/// ```dart
/// MaterialApp(
///   theme: LatticeTheme.dark(),
///   // or: theme: LatticeTheme.light(),
///   // or: theme: LatticeTheme.highContrast(),
/// )
/// ```
class LatticeTheme {
  LatticeTheme._();

  /// Dark theme — the default Lattice appearance.
  static ThemeData dark() => _build(LatticeColorScheme.dark, isDark: true);

  /// Light theme for daylight/indoor use.
  static ThemeData light() => _build(LatticeColorScheme.light, isDark: false);

  /// High-contrast green phosphor theme for outdoor/NVG field use.
  static ThemeData highContrast() => _build(LatticeColorScheme.highContrast, isDark: true);

  static ThemeData _build(LatticeColorScheme colors, {bool isDark = true}) {
    final typography = LatticeTypeScale(colors);
    final interaction = identical(colors, LatticeColorScheme.highContrast)
        ? LatticeInteractionTokens.highContrast
        : identical(colors, LatticeColorScheme.light)
            ? LatticeInteractionTokens.light
            : LatticeInteractionTokens.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: colors.accent,
        surface: colors.surface,
        error: colors.error,
        onPrimary: colors.onAccent,
        onSurface: colors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        bodySmall: typography.small,
        bodyMedium: typography.body,
        bodyLarge: typography.bodyMedium,
        titleSmall: typography.buttonLabel,
        titleMedium: typography.title,
        titleLarge: typography.titleLarge,
        labelSmall: typography.sectionLabel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.borderActive),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.borderActive),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.iconActive),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
          ),
          minimumSize: const Size(0, LatticeSpacing.touchTarget),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(colors.iconActive),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.accent
                : colors.inactive),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.iconActive
                : Colors.transparent),
        checkColor: WidgetStateProperty.all(colors.background),
        side: BorderSide(color: colors.inactive),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      extensions: [
        LatticeThemeExtension(
          colors: colors,
          typography: typography,
          interaction: interaction,
        ),
      ],
    );
  }
}
