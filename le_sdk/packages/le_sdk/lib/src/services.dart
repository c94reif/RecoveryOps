import 'dart:typed_data';

import 'package:lattice_common/lattice_common.dart';

import 'types.dart';

export 'package:lattice_common/lattice_common.dart';
export 'mesh_item_store_service.dart';
export 'messaging_service.dart';
export 'network_service.dart';

/// Access to map and location features.
abstract class MapService {
  // ---------------------------------------------------------------------------
  // Interactive
  // ---------------------------------------------------------------------------

  /// Prompt the user to pick a location on the map.
  /// Returns null if the user cancels.
  Future<LatLng?> pickLocation();

  /// Prompt the user to draw a polygon on the map by tapping multiple vertices.
  ///
  /// The host takes over the screen — the extension panel is hidden and a
  /// host-rendered draw toolbar appears (vertex counter, Undo, Done, Cancel).
  /// Each vertex tap immediately updates a live preview polygon on the map.
  /// The preview is managed entirely by the host; the plugin does not need
  /// to call addPolygon separately.
  ///
  /// Returns the closed ring (first vertex repeated as last, ≥ 4 entries for
  /// a valid polygon with ≥ 3 unique vertices) when the user taps Done, or
  /// null if they tap Cancel.
  ///
  /// [previewStrokeColor] — hex color for the in-progress polygon outline.
  ///   Defaults to '#63FFFF' (friendly cyan).
  /// [previewFillColor] — hex color + alpha for the in-progress fill.
  ///   Defaults to '#63FFFF0D' (5% opacity cyan).
  /// [toolbarHint] — instruction text shown in the host's top toolbar bar.
  ///   Defaults to 'Tap the map to add vertices'.
  ///
  /// Standalone degradation: [StubExtensionContext] returns null — a host
  /// connection is required for map interaction.
  Future<List<LatLng>?> drawPolygon({
    String? previewStrokeColor,
    String? previewFillColor,
    String? toolbarHint,
  });

  /// Prompt the user to draw a polyline (open path) on the map by tapping
  /// multiple points in order.
  ///
  /// Like [drawPolygon] the host takes over the screen — the extension panel is
  /// hidden and a host-rendered draw toolbar appears (point counter, Undo, Done,
  /// Cancel). Each tap immediately appends a point and updates a live preview
  /// polyline; unlike [drawPolygon] the path is NOT closed into a ring and there
  /// is no fill.
  ///
  /// Returns the ordered points (≥ 2) when the user taps Done, or null if they
  /// tap Cancel. This is the natural interaction for laying a route: tap to lay
  /// or extend the line, then Done — no per-point confirmation.
  ///
  /// [previewColor] — hex color for the in-progress line. Defaults to the
  ///   friendly cyan used by [drawPolygon].
  /// [toolbarHint] — instruction text shown in the host's top toolbar.
  ///   Defaults to 'Tap the map to add route points'.
  ///
  /// Standalone degradation: [StubExtensionContext] returns null.
  Future<List<LatLng>?> drawPolyline({
    String? previewColor,
    double? previewWidth,
    String? toolbarHint,
  });

  // ---------------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------------

  /// Place a marker on the map. Returns the marker's unique ID.
  ///
  /// If [icon] is provided, renders a built-in SVG icon tinted by
  /// [disposition] (defaults to [MarkerDisposition.unknown] if omitted).
  /// If [icon] is omitted, renders a plain colored circle (original behavior).
  /// When [disposition] is set, [color] is ignored.
  Future<String> addMarker(
    LatLng location, {
    String? label,
    String? color,
    MarkerIcon? icon,
    MarkerDisposition? disposition,
  });

  /// Remove a previously placed marker by its [id].
  Future<void> removeMarker(String id);

  /// Get all markers placed by this extension.
  Future<List<MapMarker>> getMarkers();

  /// Remove all markers placed by this extension.
  Future<void> clearMarkers();

  // ---------------------------------------------------------------------------
  // Polylines
  // ---------------------------------------------------------------------------

  /// Draw a polyline on the map connecting the given points in order.
  /// [id] uniquely identifies this polyline so it can be updated or removed;
  /// re-calling with the same [id] replaces the existing line (upsert).
  /// [color] is a hex string (e.g. '#FF6B35').
  /// [width] is the stroke width in logical pixels (defaults to the host's
  /// standard line width when omitted).
  /// [dashPattern] is an OpenLayers-style dash array in pixels
  /// (e.g. `[10, 6]` for a dashed line); omit or pass null for a solid line.
  /// [opacity] is 0..1 (defaults to the host's standard line opacity); use a
  /// low value to render a route faded (e.g. a CLOSED route).
  Future<void> addPolyline(
    String id,
    List<LatLng> points, {
    String? color,
    double? width,
    List<double>? dashPattern,
    double? opacity,
  });

  /// Remove a previously drawn polyline by its [id].
  Future<void> removePolyline(String id);

  /// Remove all polylines placed by this extension.
  Future<void> clearPolylines();

  // ---------------------------------------------------------------------------
  // Polygons
  // ---------------------------------------------------------------------------

  /// Draw a polygon on the map using the given ring of points.
  /// [id] uniquely identifies this polygon so it can be updated or removed.
  /// [strokeColor] and [fillColor] are hex strings (e.g. '#FF6B35').
  Future<void> addPolygon(
    String id,
    List<LatLng> points, {
    String? strokeColor,
    String? fillColor,
  });

  /// Update a previously drawn polygon by its [id].
  Future<void> updatePolygon(
    String id,
    List<LatLng> points, {
    String? strokeColor,
    String? fillColor,
  });

  /// Remove a previously drawn polygon by its [id].
  Future<void> removePolygon(String id);

  // ---------------------------------------------------------------------------
  // Tactical Graphics
  // ---------------------------------------------------------------------------

  /// Draw a 2525 tactical graphic on the map.
  /// [id] uniquely identifies this TG so it can be updated or removed.
  /// [sidc] is the 2525C SIDC string.
  /// [points] is the anchor ring; [points.first] is used as the anchor for
  /// single-anchor SIDCs.
  /// [modifiers] is an optional map of 2525 modifier keys to values.
  Future<void> addTacticalGraphic(
    String id,
    String sidc,
    List<LatLng> points, {
    Map<String, String>? modifiers,
  });

  /// Update a previously drawn tactical graphic by its [id].
  Future<void> updateTacticalGraphic(
    String id, {
    String? sidc,
    List<LatLng>? points,
    Map<String, String>? modifiers,
  });

  /// Remove a previously drawn tactical graphic by its [id].
  Future<void> removeTacticalGraphic(String id);

  // ---------------------------------------------------------------------------
  // Camera / viewport
  // ---------------------------------------------------------------------------

  /// Animate the map camera to the given location.
  Future<void> flyTo(LatLng location, {double? zoom});

  /// Convert a geographic location to logical screen pixel coordinates.
  /// Returns null if the map is not ready or the location is off-screen.
  /// Useful for test tooling that needs to synthesize taps on map markers
  /// (the OpenLayers layer renders markers inside a platform WebView, so
  /// tapping a marker requires resolving its on-screen pixel position).
  Future<ScreenPoint?> getPixelFromLocation(LatLng location);

  /// Simulate a user tap on the marker identified by [entityId], bypassing
  /// the WebView hit-test. Needed because synthesized pointer events do not
  /// reliably propagate through the OpenLayers platform view — this fires
  /// the host's own marker-tap callback directly, so the MarkerContextMenu
  /// (Task / CFF / Details) renders exactly as if the user had tapped the
  /// icon on screen. Returns false if no marker with that entity ID exists
  /// or its position cannot be resolved to a pixel.
  Future<bool> simulateMarkerTap(String entityId);

  /// Capture the on-screen map as PNG bytes, with this extension's own map
  /// features (polylines, tactical graphics, markers) baked in — they render in
  /// the same WebView as the basemap, so one capture yields map + overlay
  /// together.
  ///
  /// When [quad] is given as four AOI corners `[nw, ne, se, sw]` (geographic
  /// [LatLng]), the captured map is squared to the page — an axis-aligned
  /// extract with the region upright regardless of its on-map rotation — and a
  /// north-pointing compass is drawn. The corners are resolved to screen pixels
  /// inside the settled capture frame (not beforehand), so the crop stays
  /// aligned even if the camera is still animating. [columnLabels]/[rowLabels],
  /// when given, are drawn along the top and left margins of the squared
  /// extract. Without [quad], the whole visible viewport is returned.
  ///
  /// Returns null when capture is unsupported (non-Android / desktop CEF) or
  /// the map isn't ready — callers should fall back to their own rendering.
  Future<Uint8List?> captureMap({
    List<LatLng>? quad,
    List<String>? columnLabels,
    List<String>? rowLabels,
  });
}

/// Access to user input features.
abstract class SpeechService {
  /// Start speech-to-text dictation via the native recognizer.
  /// Returns the recognized text, or null if cancelled / no speech detected.
  Future<String?> dictate();
}

/// Access to device location (GPS).
abstract class LocationService {
  /// Get the device's current GPS location.
  /// Returns null if location services are unavailable or permission is denied.
  Future<LatLng?> getCurrentLocation();
}

/// Persistent per-extension key-value storage.
/// Values are always strings — serialize complex data as JSON.
abstract class StorageService {
  /// Read a value. Returns null if the key does not exist.
  Future<String?> read(String key);

  /// Write a value.
  Future<void> write(String key, String value);

  /// Delete a value.
  Future<void> delete(String key);
}

/// Access to Lattice entity data.
abstract class EntityService {
  /// Publish (create or update) an entity via the backend.
  Future<PublishEntityResult> publishEntity(PublishEntityRequest request);

  /// Get a single entity by ID.
  Future<Entity?> getEntity(String entityId);

  /// Stream entity component updates (upserts and deletes).
  Stream<EntityEvent> streamEntityComponents();

  /// Get all entities currently in the repository.
  Future<List<Entity>> getEntities();

  /// Search entities by name substring (case-insensitive).
  Future<List<Entity>> searchEntities(String query);

  /// Find entities within a radius of a point (haversine).
  Future<List<Entity>> getNearbyEntities(
      double lat, double lon, double radiusMeters);

  /// Create or update an entity using a full [Entity] object.
  /// Returns the entity ID assigned by the backend.
  Future<String> upsertEntity(Entity entity);

  /// Delete (retract) an entity by ID. Publishes `isLive: false` through the
  /// host entity pipeline, which fires an [EntityDelete] on
  /// [streamEntityComponents] and removes the entity from the map/data model.
  Future<void> deleteEntity(String entityId);
}

/// Access to Lattice task data.
abstract class TaskService {
  /// Create a new task.
  Future<TaskData> createTask(CreateTaskParams params);

  /// Get a single task by ID.
  Future<TaskData?> getTask(String taskId);

  /// Update task status.
  Future<TaskData> updateStatus(String taskId, int newRawStatus,
      {String? errorMessage, int? errorCode});

  /// Cancel a task.
  Future<TaskData> cancelTask(String taskId, {String? reason});

  /// Query tasks with optional filters.
  Future<List<TaskData>> queryTasks({
    String? assigneeEntityId,
    String? authorUserId,
    List<TaskStatusGroup>? statusGroups,
    String? specTypeUrl,
  });

  /// Listen for task assignments as an agent.
  Stream<TaskData> listenAsAgent();
}
