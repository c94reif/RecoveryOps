import 'package:flutter/foundation.dart';

import 'ai_service.dart';
import 'peripheral_services.dart';
import 'services.dart';
import 'types.dart';
import 'ui_service.dart';

// Conditional import: on web targets, loads WebExtensionContext;
// on native targets, loads StubExtensionContext (which also has a
// static `connect` method with the same signature).
import 'stub_extension_context.dart'
    if (dart.library.js_interop) 'web_extension_context.dart' as platform_impl;

/// Context provided to extensions, giving them access to host
/// capabilities via domain-grouped accessors.
abstract class ExtensionContext {
  /// Information about the host environment.
  /// Synchronous — host info is known at context creation time.
  HostInfo get hostInfo;

  /// Location/map operations.
  MapService get map;

  /// Device location (GPS).
  LocationService get location;

  /// User input operations (speech, etc.).
  SpeechService get speech;

  /// Persistent per-extension key-value storage.
  StorageService get storage;

  /// Contacts, messaging, and peer discovery.
  MessagingService get messaging;

  EntityService get entities;
  TaskService get tasks;
  AiService get ai;

  /// Host UI control and introspection.
  UiService get ui;

  /// Raw hardware device access (USB serial, etc.).
  DeviceService get device;

  /// Peripheral sensor event buses (range finder, etc.).
  PeripheralsService get peripherals;

  /// Close this extension (panel or overlay tab).
  void close();

  /// Connect to the host environment.
  /// - In web mode: wraps window.LatticeEdgeExtension via dart:js_interop
  /// - In standalone mode: returns a stub with sensible defaults
  ///
  /// Extensions call this in their main.dart:
  /// ```dart
  /// final context = await ExtensionContext.connect();
  /// runApp(MyApp(context: context));
  /// ```
  static Future<ExtensionContext> connect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (kIsWeb) {
      // Conditional import resolves to WebExtensionContext on web.
      // If the bridge isn't available (standalone preview), fall back to stub.
      try {
        return await platform_impl.WebExtensionContext.connect(timeout: timeout);
      } catch (_) {
        return platform_impl.StubExtensionContext.connect(timeout: timeout);
      }
    }
    // Conditional import resolves to StubExtensionContext on native
    return platform_impl.StubExtensionContext.connect(timeout: timeout);
  }
}
