import 'types.dart';

/// Host UI control and introspection for extensions.
abstract class UiService {
  /// Navigate to a top-level view.
  /// [viewId]: 'map', 'lca', 'fleet_manager', 'atak_bridge'
  Future<void> navigateTo(String viewId);

  /// Get the currently active top-level view ID.
  Future<String> getActiveView();

  /// Open a right panel by ID.
  /// [panelId]: 'notifications', 'tasks', 'chat', 'entities', 'overlays',
  ///            'applications', 'settings', 'latticeAi'
  ///
  /// An unrecognised id is ignored. 'applications' is the All Applications
  /// launcher, which replaced the former 'plugins' tab — extensions are listed
  /// there now.
  Future<void> openPanel(String panelId);

  /// Close the currently open right panel.
  Future<void> closePanel();

  /// Get the currently open right panel ID, or null if none.
  Future<String?> getActivePanel();

  /// Activate an extension by its ID.
  Future<void> openExtension(String extensionId);

  /// Read (and clear) the launch arguments the host queued for this extension's
  /// most recent activation, or null when there are none. The host sets these
  /// when opening the plug-in from a contextual entry point — e.g. right-click
  /// an extension-managed entity → "Open in plugin" passes `{'action': 'openInPlugin',
  /// 'entityId': ...}`. Consumed on read, so a later manual open returns null.
  Future<Map<String, dynamic>?> getLaunchArgs();

  /// DEBUG-ONLY: read a JSON command the host exposes from an app-external file
  /// (writable via `adb push`). Returns the raw JSON string, or null when no
  /// file / unsupported. Used by E2E test harnesses to drive a plug-in without
  /// tapping its canvas. Strip before ship.
  Future<String?> debugReadCommand();

  /// Close an extension by its ID.
  Future<void> closeExtension(String extensionId);

  /// Get the active panel extension ID, or null.
  Future<String?> getActiveExtension();

  /// Whether location picker mode is active.
  Future<bool> isLocationPickerActive();

  /// Whether push-to-talk is active.
  Future<bool> isPttActive();

  /// Whether the system status bar is enabled.
  Future<bool> isStatusBarEnabled();

  /// Open a left panel by ID.
  ///
  /// **Deprecated — the left sidebar was removed** (its navigation moved to the
  /// right rail). Every implementation is a no-op; [getActiveLeftPanel] always
  /// reports null. Use [openPanel] with a right-panel id instead — extensions
  /// are listed under `'applications'`.
  ///
  /// Declared only so an extension built against an older SDK keeps compiling.
  /// Callers get a deprecation warning; implementers still supply a no-op body,
  /// because `implements UiService` does not inherit default bodies.
  @Deprecated(
    'The left sidebar was removed; this is a no-op. Use openPanel() instead.',
  )
  Future<void> openLeftPanel(String panelId);

  /// Close the currently open left panel.
  ///
  /// **Deprecated — no-op.** See [openLeftPanel].
  @Deprecated(
    'The left sidebar was removed; this is a no-op. Use closePanel() instead.',
  )
  Future<void> closeLeftPanel();

  /// Get the currently open left panel ID, or null if none.
  ///
  /// **Deprecated — always null.** See [openLeftPanel].
  @Deprecated(
    'The left sidebar was removed; this always returns null. '
    'Use getActivePanel() instead.',
  )
  Future<String?> getActiveLeftPanel();

  /// Show a floating banner overlay with a message.
  Future<void> showBanner(String message);

  /// Hide the floating banner overlay.
  Future<void> hideBanner();

  /// Resize the extension panel to one of the preset [PanelSize] widths.
  ///
  /// - [PanelSize.small]: the default plugin-drawer width.
  /// - [PanelSize.medium]: 70% of the screen width.
  /// - [PanelSize.large]: the full content area (screen minus the nav rail).
  ///
  /// After animating, the extension reloads once — in-memory UI state is lost;
  /// persist anything you need via [StorageService] before calling. Calling
  /// with the current size is a no-op (no reload). A request that arrives while
  /// a resize is still settling is ignored.
  Future<void> setPanelSize(PanelSize size);

  /// Get the panel's current preset size.
  ///
  /// Returns the nearest preset for the panel's current width. If the user has
  /// manually dragged the panel to a custom width, this returns the closest
  /// preset rather than an exact match.
  Future<PanelSize> getPanelSize();

  /// Show a transient, dismissable toast notification.
  ///
  /// Unlike [showBanner] (a persistent overlay), this surfaces a queued toast
  /// that auto-dismisses. The host owns presentation; the extension only
  /// supplies content. [type] is one of 'info' | 'success' | 'warning' |
  /// 'error' (defaults to 'info'); [priority] is 'routine' | 'priority' |
  /// 'immediate' (defaults to 'routine') and influences ordering / dwell time.
  /// Unknown values fall back to the defaults host-side.
  Future<void> showToast(
    String message, {
    String type,
    String priority,
  });

  /// Switch an extension's display mode ('panel' or 'overlay').
  /// Overlay mode moves the extension to a small tab, keeping it alive.
  Future<void> setExtensionDisplayMode(String extensionId, String mode);

  /// Reset UI to a clean state: close all panels, extensions, pickers,
  /// navigate to map. Used for test isolation between macro runs.
  Future<void> resetUi();

  /// Dismiss the soft keyboard by unfocusing the currently-focused widget.
  /// No-op if no widget has focus. Used by tests after `enterText` when the
  /// next intended tap is on a widget that the keyboard would cover.
  Future<void> hideKeyboard();

  /// Set manual location override (lat/lon).
  Future<void> setManualLocation(double lat, double lon);

  /// Clear manual location override (revert to GPS).
  Future<void> clearManualLocation();

  /// Whether manual location override is enabled.
  Future<bool> isManualLocationEnabled();

  /// Tap a widget matching the selector.
  /// Selector keys: 'text' (String), 'icon' (String), 'index' (int, default 0)
  Future<bool> tapWidget(Map<String, dynamic> selector);

  /// Dispatch a synthetic tap at absolute screen coordinates (logical pixels).
  /// Intended for targets that aren't reachable via [tapWidget] — map
  /// symbols, custom-painted overlays, WebView content — where no matching
  /// Text or Icon widget exists.
  Future<void> tapAt(double x, double y);

  /// Dispatch a synthetic long-press at absolute screen coordinates.
  /// Default hold exceeds Flutter's 500ms `kLongPressTimeout` so
  /// `onLongPress` handlers (e.g. the map's AddObjectMenu) fire.
  Future<void> longPressAt(double x, double y, {int holdMs});

  /// Enter text into a TextField matching the selector.
  /// Selector keys: 'hint' (String), 'index' (int, default 0)
  Future<bool> enterText(Map<String, dynamic> selector, String text);

  /// Get all visible text labels in the current widget tree.
  Future<List<String>> getVisibleLabels();

  /// Block until a TestEventBus event of [type] (optionally also matching
  /// every key/value in [match]) is observed, or [timeoutMs] elapses.
  ///
  /// Keys in [match] beginning with `task.` match against the nested `task`
  /// map of the event (e.g. `{"task.taskId": "abc"}`); all other keys match
  /// top-level event fields.
  ///
  /// Returns the matched event JSON, or null on timeout. Intended for
  /// post-action validation: "did the task actually reach the other side?",
  /// "did the task detail panel actually open?", etc.
  ///
  /// Only meaningful inside the host app; stub/web implementations return
  /// null immediately.
  Future<Map<String, dynamic>?> waitForEvent(
    String type, {
    Map<String, dynamic>? match,
    int timeoutMs = 30000,
    int lookbackMs = 2500,
  });
}
