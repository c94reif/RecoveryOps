// GENERATED — do not edit by hand.
// Source: design-tokens/tokens.json
// Run: dart run scripts/generate-tokens.dart

import 'package:flutter/material.dart';

/// Lattice color scheme — instance-based for runtime theme switching.
///
/// Generated from design-tokens/tokens.json.
class LatticeColorScheme {
  const LatticeColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceSection,
    required this.surfaceElevated,
    required this.border,
    required this.borderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textLabel,
    required this.inactive,
    required this.iconActive,
    required this.accent,
    required this.success,
    required this.error,
    required this.statusPending,
    required this.statusActive,
    required this.latticeDispositionHostile,
    required this.latticeDispositionSuspect,
    required this.latticeDispositionUnknown,
    required this.latticeDispositionAssumedFriendly,
    required this.latticeDispositionFriendly,
    required this.latticeDispositionNeutral,
    required this.latticeDispositionPending,
    required this.entityHostile,
    required this.entityFriendly,
    required this.entityAsset,
    required this.entityAtak,
    required this.onAccent,
    required this.onError,
    required this.onWarning,
    required this.onSuccess,
    required this.geoEntityRed,
    required this.geoEntityOrange,
    required this.geoEntityYellow,
    required this.geoEntityGreen,
    required this.geoEntityBlue,
    required this.geoEntityIndigo,
    required this.geoEntityViolet,
  });

  final Color background;

  final Color surface;

  final Color surfaceSection;

  final Color surfaceElevated;

  final Color border;

  final Color borderActive;

  final Color textPrimary;

  final Color textSecondary;

  final Color textMuted;

  final Color textLabel;

  final Color inactive;

  final Color iconActive;

  final Color accent;

  final Color success;

  final Color error;

  final Color statusPending;

  final Color statusActive;

  final Color latticeDispositionHostile;

  final Color latticeDispositionSuspect;

  final Color latticeDispositionUnknown;

  final Color latticeDispositionAssumedFriendly;

  final Color latticeDispositionFriendly;

  final Color latticeDispositionNeutral;

  final Color latticeDispositionPending;

  final Color entityHostile;

  final Color entityFriendly;

  final Color entityAsset;

  final Color entityAtak;

  final Color onAccent;

  final Color onError;

  final Color onWarning;

  final Color onSuccess;

  final Color geoEntityRed;

  final Color geoEntityOrange;

  final Color geoEntityYellow;

  final Color geoEntityGreen;

  final Color geoEntityBlue;

  final Color geoEntityIndigo;

  final Color geoEntityViolet;

  /// Default dark theme — matches the existing Lattice style guide.
  static const dark = LatticeColorScheme(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF111111),
    surfaceSection: Color(0xFF161616),
    surfaceElevated: Color(0xFF1A1A1A),
    border: Color(0xFF1D1D1D),
    borderActive: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF878787),
    textMuted: Color(0xFF545454),
    textLabel: Color(0xFF999999),
    inactive: Color(0xFF666666),
    iconActive: Color(0xFFFFFFFF),
    accent: Color(0xFF334EFF),
    success: Color(0xFF4BAF4F),
    error: Color(0xFFFF4444),
    statusPending: Color(0xFFFFB300),
    statusActive: Color(0xFF42A5F4),
    latticeDispositionHostile: Color(0xFFF23933),
    latticeDispositionSuspect: Color(0xFFF49200),
    latticeDispositionUnknown: Color(0xFFFCFF00),
    latticeDispositionAssumedFriendly: Color(0xFF55FE2E),
    latticeDispositionFriendly: Color(0xFF63FFFF),
    latticeDispositionNeutral: Color(0xFFF449CF),
    latticeDispositionPending: Color(0xFFD7D8DB),
    entityHostile: Color(0xFFD84949),
    entityFriendly: Color(0xFF4990D8),
    entityAsset: Color(0xFF49D8A0),
    entityAtak: Color(0xFFD88749),
    onAccent: Color(0xFFFFFFFF),
    onError: Color(0xFFFFFFFF),
    onWarning: Color(0xFF1A1A1A),
    onSuccess: Color(0xFFFFFFFF),
    geoEntityRed: Color(0xFFFF0000),
    geoEntityOrange: Color(0xFFFFA500),
    geoEntityYellow: Color(0xFFFFFF00),
    geoEntityGreen: Color(0xFF00FF00),
    geoEntityBlue: Color(0xFF0000FF),
    geoEntityIndigo: Color(0xFF4B0082),
    geoEntityViolet: Color(0xFF8F00FF),
  );

  /// Light theme for daylight/indoor use.
  static const light = LatticeColorScheme(
    background: Color(0xFFF4F4F4),
    surface: Color(0xFFFFFFFF),
    surfaceSection: Color(0xFFF6F6F6),
    surfaceElevated: Color(0xFFEFEFEF),
    border: Color(0xFFDFDFDF),
    borderActive: Color(0xFFCCCCCC),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF666666),
    textMuted: Color(0xFF999999),
    textLabel: Color(0xFF545454),
    inactive: Color(0xFFBABABA),
    iconActive: Color(0xFF1A1A1A),
    accent: Color(0xFF5569ED),
    success: Color(0xFF388E3B),
    error: Color(0xFFD32F2F),
    statusPending: Color(0xFFF47E16),
    statusActive: Color(0xFF1875D1),
    latticeDispositionHostile: Color(0xFFF23933),
    latticeDispositionSuspect: Color(0xFFF49200),
    latticeDispositionUnknown: Color(0xFFFCFF00),
    latticeDispositionAssumedFriendly: Color(0xFF55FE2E),
    latticeDispositionFriendly: Color(0xFF63FFFF),
    latticeDispositionNeutral: Color(0xFFF449CF),
    latticeDispositionPending: Color(0xFFD7D8DB),
    entityHostile: Color(0xFFC62828),
    entityFriendly: Color(0xFF1564BF),
    entityAsset: Color(0xFF2D7C31),
    entityAtak: Color(0xFFE65000),
    onAccent: Color(0xFFFFFFFF),
    onError: Color(0xFFFFFFFF),
    onWarning: Color(0xFF1A1A1A),
    onSuccess: Color(0xFFFFFFFF),
    geoEntityRed: Color(0xFFFF0000),
    geoEntityOrange: Color(0xFFFFA500),
    geoEntityYellow: Color(0xFFFFFF00),
    geoEntityGreen: Color(0xFF00FF00),
    geoEntityBlue: Color(0xFF0000FF),
    geoEntityIndigo: Color(0xFF4B0082),
    geoEntityViolet: Color(0xFF8F00FF),
  );

  /// High-contrast green phosphor theme for outdoor/NVG field use.
  static const highContrast = LatticeColorScheme(
    background: Color(0xFF000000),
    surface: Color(0xFF0A110A),
    surfaceSection: Color(0xFF0A160A),
    surfaceElevated: Color(0xFF0C1A0C),
    border: Color(0xFF1A2D1A),
    borderActive: Color(0xFF2D492D),
    textPrimary: Color(0xFFCBFF72),
    textSecondary: Color(0xFF00B32F),
    textMuted: Color(0xFF00661F),
    textLabel: Color(0xFF00CC33),
    inactive: Color(0xFF1A3A10),
    iconActive: Color(0xFFC3FF00),
    accent: Color(0xFF10A000),
    success: Color(0xFF00FF41),
    error: Color(0xFFFF3333),
    statusPending: Color(0xFFCCCC00),
    statusActive: Color(0xFF00CCFF),
    latticeDispositionHostile: Color(0xFFFF4444),
    latticeDispositionSuspect: Color(0xFFFFAA00),
    latticeDispositionUnknown: Color(0xFFFFFF33),
    latticeDispositionAssumedFriendly: Color(0xFF66FF44),
    latticeDispositionFriendly: Color(0xFF77FFFF),
    latticeDispositionNeutral: Color(0xFFFF66DD),
    latticeDispositionPending: Color(0xFFDDDDDD),
    entityHostile: Color(0xFFFF5454),
    entityFriendly: Color(0xFF54AAFF),
    entityAsset: Color(0xFF54FFAA),
    entityAtak: Color(0xFFFFAA54),
    onAccent: Color(0xFFCBFF72),
    onError: Color(0xFFCBFF72),
    onWarning: Color(0xFF000000),
    onSuccess: Color(0xFFCBFF72),
    geoEntityRed: Color(0xFFFF0000),
    geoEntityOrange: Color(0xFFFFA500),
    geoEntityYellow: Color(0xFFFFFF00),
    geoEntityGreen: Color(0xFF00FF00),
    geoEntityBlue: Color(0xFF0000FF),
    geoEntityIndigo: Color(0xFF4B0082),
    geoEntityViolet: Color(0xFF8F00FF),
  );

}
