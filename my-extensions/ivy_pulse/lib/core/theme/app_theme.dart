import 'package:flutter/material.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';

final Color masterChiefGreen = const Color(0xFF4A7820);
final Color gunMetalGrey = const Color(0xFF0A0B0D);

const Color bgDark = Color(0xFF141619);
const Color surface = Color(0xFF22262B);
const Color surfaceLight = Color(0xFF2A2F34);
const Color border = Color(0xFF3C4147);
const Color textPrimary = Color(0xFFE8EAED);
const Color textSecondary = Color(0xFF9AA0A8);
const Color greenGlow = Color(0x264A7820);

// ── PMCS status palette ──────────────────────────────────────────────────
// Fault symbols must read at arm's length in sunlight and stay distinguishable
// to the red-green colour blind, so severity is carried by shape and label in
// the UI as well as by these colours.

/// Serviceable — the operator found nothing wrong.
const Color serviceableGreen = Color(0xFF3FA34D);
const Color serviceableGlow = Color(0x263FA34D);

/// RED X — Not Mission Capable, the vehicle is deadlined.
const Color redXRed = Color(0xFFD64545);
const Color redXGlow = Color(0x26D64545);

/// CIRCLE X — operable only on a commander-approved mission-essential run.
const Color circleXAmber = Color(0xFFD9A125);
const Color circleXGlow = Color(0x26D9A125);

/// DASH — a minor deficiency that may be deferred.
const Color dashBlue = Color(0xFF4A90D9);
const Color dashGlow = Color(0x264A90D9);

/// Colour for a fault symbol.
Color severityColor(FaultSeverity severity) => switch (severity) {
      FaultSeverity.redX => redXRed,
      FaultSeverity.circleX => circleXAmber,
      FaultSeverity.dash => dashBlue,
    };

/// Translucent fill matching [severityColor], for chips and card backgrounds.
Color severityGlow(FaultSeverity severity) => switch (severity) {
      FaultSeverity.redX => redXGlow,
      FaultSeverity.circleX => circleXGlow,
      FaultSeverity.dash => dashGlow,
    };

/// Redundant glyph so severity is never conveyed by colour alone.
IconData severityIcon(FaultSeverity severity) => switch (severity) {
      FaultSeverity.redX => Icons.dangerous_outlined,
      FaultSeverity.circleX => Icons.error_outline,
      FaultSeverity.dash => Icons.remove_circle_outline,
    };

// ── Touch targets ────────────────────────────────────────────────────────
// Lattice Edge is operated in gloves. Nothing tappable goes below these.

/// Minimum height for any tappable control.
const double minTouchTarget = 48;

/// Height for the fault-selection buttons. Above the 48px minimum so a
/// two-line condition still reads, but no taller — the panel the host gives
/// this extension is barely 370 logical pixels high in landscape, and a whole
/// TM check has to fit inside it.
const double faultButtonHeight = 52;

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: masterChiefGreen,
    brightness: Brightness.dark,
    primary: masterChiefGreen,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: surfaceLight,
  ),
  scaffoldBackgroundColor: gunMetalGrey,
  splashColor: greenGlow,
  highlightColor: greenGlow,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      color: textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
    bodyMedium: TextStyle(fontSize: 13, color: textSecondary),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: bgDark,
    foregroundColor: masterChiefGreen,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: masterChiefGreen,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: bgDark,
    selectedItemColor: masterChiefGreen,
    unselectedItemColor: textSecondary,
    selectedLabelStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 11,
    ),
    unselectedLabelStyle: const TextStyle(fontSize: 10),
    type: BottomNavigationBarType.fixed,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
    hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: border, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: masterChiefGreen, width: 1.5),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
    prefixIconColor: textSecondary,
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return greenGlow;
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return masterChiefGreen;
        return textSecondary;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: masterChiefGreen, width: 1);
        }
        return const BorderSide(color: border, width: 1);
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      overlayColor: WidgetStateProperty.all(greenGlow),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: masterChiefGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: masterChiefGreen,
      backgroundColor: greenGlow,
      side: BorderSide(color: masterChiefGreen, width: 1),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: masterChiefGreen,
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: textSecondary,
      hoverColor: greenGlow,
    ),
  ),
  cardTheme: CardThemeData(
    color: surface,
    surfaceTintColor: Colors.transparent,
    elevation: 3,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: border, width: 1),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),
  listTileTheme: const ListTileThemeData(
    dense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    iconColor: textSecondary,
    textColor: textPrimary,
    subtitleTextStyle: TextStyle(color: textSecondary, fontSize: 11),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: border,
    thickness: 0.5,
    space: 1,
  ),
  badgeTheme: BadgeThemeData(
    backgroundColor: Colors.red.shade700,
    textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return const Color(0xFFB0B0B0);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return masterChiefGreen;
      return surfaceLight;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.transparent;
      return border;
    }),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: masterChiefGreen,
  ),
);
