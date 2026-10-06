import 'package:flutter/material.dart';

@immutable
class CacOcrTheme extends ThemeExtension<CacOcrTheme> {
  final Color text;
  final Color mutedText;
  final Color surface;
  final Color raisedSurface;
  final Color outline;
  final Color accent;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;

  const CacOcrTheme({
    required this.text,
    required this.mutedText,
    required this.surface,
    required this.raisedSurface,
    required this.outline,
    required this.accent,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
  });

  static const double minTouchTarget = 48;

  factory CacOcrTheme.fromColorScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final success = dark ? const Color(0xFF3FA34D) : const Color(0xFF2E7D32);
    final warning = dark ? const Color(0xFFD9A125) : const Color(0xFF8A6100);
    return CacOcrTheme(
      text: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      surface: scheme.surfaceContainer,
      raisedSurface: scheme.surfaceContainerHighest,
      outline: scheme.outlineVariant,
      accent: scheme.primary,
      success: success,
      successContainer: success.withValues(alpha: 0.15),
      warning: warning,
      warningContainer: warning.withValues(alpha: 0.15),
      danger: scheme.error,
      dangerContainer: scheme.error.withValues(alpha: 0.15),
    );
  }

  static CacOcrTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CacOcrTheme>() ??
        CacOcrTheme.fromColorScheme(theme.colorScheme);
  }

  @override
  CacOcrTheme copyWith({
    Color? text,
    Color? mutedText,
    Color? surface,
    Color? raisedSurface,
    Color? outline,
    Color? accent,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
  }) =>
      CacOcrTheme(
        text: text ?? this.text,
        mutedText: mutedText ?? this.mutedText,
        surface: surface ?? this.surface,
        raisedSurface: raisedSurface ?? this.raisedSurface,
        outline: outline ?? this.outline,
        accent: accent ?? this.accent,
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        danger: danger ?? this.danger,
        dangerContainer: dangerContainer ?? this.dangerContainer,
      );

  @override
  CacOcrTheme lerp(CacOcrTheme? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CacOcrTheme(
      text: mix(text, other.text),
      mutedText: mix(mutedText, other.mutedText),
      surface: mix(surface, other.surface),
      raisedSurface: mix(raisedSurface, other.raisedSurface),
      outline: mix(outline, other.outline),
      accent: mix(accent, other.accent),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
    );
  }
}
