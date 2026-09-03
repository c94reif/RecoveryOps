import 'package:lattice_common/lattice_common.dart';

import 'types.dart';

export 'package:lattice_common/lattice_common.dart';
export 'messaging_service.dart';

/// Access to map and location features.
abstract class MapService {
  // ---------------------------------------------------------------------------
  // Interactive
  // ---------------------------------------------------------------------------

  /// Prompt the user to pick a location on the map.
  /// Returns null if the user cancels.
  Future<LatLng?> pickLocation();

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
  /// [id] uniquely identifies this polyline so it can be updated or removed.
  /// [color] is a hex string (e.g. '#FF6B35').
  Future<void> addPolyline(String id, List<LatLng> points, {String? color});

  /// Remove a previously drawn polyline by its [id].
  Future<void> removePolyline(String id);

  /// Remove all polylines placed by this extension.
  Future<void> clearPolylines();

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
