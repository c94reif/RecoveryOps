import 'package:flutter/material.dart';

import 'extension_context.dart';
import 'types.dart';

/// Abstract base class for Lattice Edge extensions.
///
/// Implement this class and register it with [ExtensionService] at app
/// startup to add a native extension.
abstract class LatticeEdgeExtension {
  /// Unique identifier for this extension.
  String get id;

  /// Display name shown in the extension grid and headers.
  String get name;

  /// Optional description shown in long-press context menus.
  String get description => '';

  /// Icon displayed in the extension grid.
  IconData get icon => Icons.extension;

  /// Optional path to a custom icon image asset (e.g. 'assets/logo.png').
  String? get iconAsset => null;

  /// Default display mode (panel or overlay). Users can override.
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  /// Build the extension's UI. Called each time the extension is activated.
  Widget build(ExtensionContext context);

  /// Called when the extension is opened/activated.
  void onActivate() {}

  /// Called when the extension is closed/deactivated.
  void onDeactivate() {}

  /// Called once during app startup after registration.
  void onInitialize() {}

  /// Called once during app startup with the full [ExtensionContext].
  ///
  /// Override this to wire up services that require SDK access at init time
  /// (e.g. [ExtensionContext.device.usbSerial], [ExtensionContext.peripherals.rangeFinder]).
  /// The default implementation is a no-op, so existing extensions are unaffected.
  void onInitializeWithContext(ExtensionContext context) {}

  /// Called during app teardown.
  void dispose() {}
}
