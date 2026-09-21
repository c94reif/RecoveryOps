/// Host UI control and introspection for extensions.
abstract class UiService {
  /// Navigate to a top-level view.
  /// [viewId]: 'map', 'lca', 'fleet_manager', 'atak_bridge'
  Future<void> navigateTo(String viewId);

  /// Get the currently active top-level view ID.
  Future<String> getActiveView();

  /// Open a right panel by ID.
  /// [panelId]: 'settings', 'latticeAi', 'entities', 'tasks',
  ///            'notifications', 'comms', 'chat', 'browser'
  Future<void> openPanel(String panelId);

  /// Close the currently open right panel.
  Future<void> closePanel();

  /// Get the currently open right panel ID, or null if none.
  Future<String?> getActivePanel();

  /// Activate an extension by its ID.
  Future<void> openExtension(String extensionId);

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
  /// [panelId]: 'plugins', 'appSwitcher'
  Future<void> openLeftPanel(String panelId);

  /// Close the currently open left panel.
  Future<void> closeLeftPanel();

  /// Get the currently open left panel ID, or null if none.
  Future<String?> getActiveLeftPanel();

  /// Show a floating banner overlay with a message.
  Future<void> showBanner(String message);

  /// Hide the floating banner overlay.
  Future<void> hideBanner();

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
