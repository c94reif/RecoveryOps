# Lattice Edge Extension SDK — API Reference

This document is the complete API reference for the Lattice Edge Extension SDK. For a tutorial-style walkthrough, see the [Extension Developer Guide](developer-guide.md).

---

## Table of Contents

- [ExtensionContext](#extensioncontext)
- [MapService](#mapservice-contextmap)
- [LocationService](#locationservice-contextlocation)
- [SpeechService](#speechservice-contextspeech)
- [StorageService](#storageservice-contextstorage)
- [MessagingService](#messagingservice-contextmessaging)
- [EntityService](#entityservice-contextentities)
- [TaskService](#taskservice-contexttasks)
- [Types](#types)
- [Error Contract](#error-contract)
- [Storage Notes](#storage-notes)

---

## ExtensionContext

The top-level object your extension uses to interact with the host. Obtain it via the static `connect()` factory.

### `ExtensionContext.connect()`

```dart
static Future<ExtensionContext> connect({
  Duration timeout = const Duration(seconds: 5),
})
```

**Description:** Connects to the host environment. In web mode, wraps the injected `window.LatticeEdgeExtension` JavaScript bridge. In standalone mode (e.g., `flutter run`), returns a `StubExtensionContext` with sensible defaults for UI iteration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `timeout` | `Duration` | 5 seconds | How long to wait for the host bridge before falling back to stub. |

**Returns:** `Future<ExtensionContext>`

**Example:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();
  runApp(MyApp(context: context));
}
```

---

### `hostInfo`

```dart
HostInfo get hostInfo
```

**Description:** Returns information about the host environment. Synchronous -- host info is cached at connection time.

**Returns:** `HostInfo`

| Field | Type | Description |
|-------|------|-------------|
| `host` | `String` | Host identifier (e.g. `'lattice-edge'`) |
| `version` | `String` | Host version |
| `extensionId` | `String` | This extension's ID |
| `callsign` | `String?` | The operator's callsign on this device, or null if not set |

**Example:**

```dart
final info = context.hostInfo;
print('Running in ${info.host} v${info.version}, extension: ${info.extensionId}');
print('Operator callsign: ${info.callsign ?? "not set"}');
```

---

### `close()`

```dart
void close()
```

**Description:** Closes this extension's panel or overlay tab. Call this when the user is done with the extension (e.g., after submitting a form).

**Example:**

```dart
await _submitReport();
context.close();
```

---

### Accessors

| Accessor | Type | Description |
|----------|------|-------------|
| `context.map` | `MapService` | Map and location features |
| `context.location` | `LocationService` | Device GPS location |
| `context.speech` | `SpeechService` | User input features (speech) |
| `context.storage` | `StorageService` | Persistent key-value storage |
| `context.messaging` | `MessagingService` | Peer discovery and messaging |
| `context.entities` | `EntityService` | Lattice entity CRUD and streaming |
| `context.tasks` | `TaskService` | Task creation, status, and agent listening |

---

## MapService (`context.map`)

Access to map and location features.

### `pickLocation()`

```dart
Future<LatLng?> pickLocation()
```

**Description:** Prompts the user to select a location on the map. The host app presents its native map picker UI. Returns `null` if the user cancels.

**Returns:** `Future<LatLng?>` -- the selected coordinate, or `null` on cancellation.

**Example:**

```dart
final loc = await context.map.pickLocation();
if (loc != null) {
  print('Selected: ${loc.latitude}, ${loc.longitude}');
}
```

---

### `addMarker()`

```dart
Future<String> addMarker(
  LatLng location, {
  String? label,
  String? color,
  MarkerIcon? icon,
  MarkerDisposition? disposition,
})
```

**Description:** Places a marker on the host map at the given coordinates. Returns a unique marker ID that can be used to update or remove the marker later. If `icon` is provided, renders a built-in SVG icon tinted by `disposition` (defaults to `MarkerDisposition.unknown` if omitted). If `icon` is omitted, renders a plain colored circle. When `disposition` is set, `color` is ignored.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | `LatLng` | Yes | The geographic coordinate for the marker. |
| `label` | `String?` | No | Optional text label displayed on the marker. |
| `color` | `String?` | No | Hex color string (e.g. `'#FF6B35'`). Defaults to host theme accent. Ignored when `disposition` is set. |
| `icon` | `MarkerIcon?` | No | Built-in icon type (e.g. `MarkerIcon.tank`, `MarkerIcon.helicopter`). |
| `disposition` | `MarkerDisposition?` | No | Military disposition for icon coloring (`hostile`, `friendly`, `neutral`, `unknown`). |

**Returns:** `Future<String>` — the marker's unique ID.

**Example:**

```dart
// Simple colored marker
final markerId = await context.map.addMarker(
  LatLng(33.7490, -84.3880),
  label: 'Rally Point Alpha',
);

// Icon marker with disposition
final iconMarkerId = await context.map.addMarker(
  LatLng(33.7500, -84.3900),
  label: 'Enemy Armor',
  icon: MarkerIcon.tank,
  disposition: MarkerDisposition.hostile,
);
```

---

### `removeMarker()`

```dart
Future<void> removeMarker(String id)
```

**Description:** Removes a previously placed marker by its ID (returned by `addMarker`).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | `String` | Yes | The marker ID returned by `addMarker`. |

**Returns:** `Future<void>`

**Example:**

```dart
final id = await context.map.addMarker(
  LatLng(33.7490, -84.3880),
  label: 'Temp',
);
// Later...
await context.map.removeMarker(id);
```

---

### `getMarkers()`

```dart
Future<List<MapMarker>> getMarkers()
```

**Description:** Returns all markers placed by this extension. Each `MapMarker` contains `id`, `latitude`, `longitude`, `label`, `color`, `icon`, and `disposition`.

**Returns:** `Future<List<MapMarker>>`

**Example:**

```dart
final markers = await context.map.getMarkers();
for (final m in markers) {
  print('${m.id}: ${m.latitude}, ${m.longitude}');
}
```

---

### `clearMarkers()`

```dart
Future<void> clearMarkers()
```

**Description:** Removes all markers placed by this extension. Does not affect markers from other extensions or the host.

**Returns:** `Future<void>`

**Example:**

```dart
await context.map.clearMarkers();
```

---

### `addPolyline()`

```dart
Future<void> addPolyline(String id, List<LatLng> points, {String? color})
```

**Description:** Draws a polyline on the map connecting the given points in order. If a polyline with the same `id` already exists, it is replaced.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | `String` | Yes | Unique identifier for this polyline (for update/removal). |
| `points` | `List<LatLng>` | Yes | Ordered list of coordinates defining the line. |
| `color` | `String?` | No | Hex color string (e.g. `'#FF6B35'`). Defaults to host theme. |

**Returns:** `Future<void>`

**Example:**

```dart
await context.map.addPolyline(
  'patrol-route',
  [LatLng(33.749, -84.388), LatLng(33.752, -84.391), LatLng(33.755, -84.385)],
  color: '#FF6B35',
);
```

---

### `removePolyline()`

```dart
Future<void> removePolyline(String id)
```

**Description:** Removes a previously drawn polyline by its `id`.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | `String` | Yes | The identifier of the polyline to remove. |

**Returns:** `Future<void>`

---

### `clearPolylines()`

```dart
Future<void> clearPolylines()
```

**Description:** Removes all polylines placed by this extension.

**Returns:** `Future<void>`

---

### `flyTo()`

```dart
Future<void> flyTo(LatLng location, {double? zoom})
```

**Description:** Animates the map camera to the given location.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | `LatLng` | Yes | The target coordinate to center the map on. |
| `zoom` | `double?` | No | Target zoom level. Defaults to 14.0. |

**Returns:** `Future<void>`

**Example:**

```dart
await context.map.flyTo(LatLng(33.7490, -84.3880), zoom: 16.0);
```

**Example:**

```dart
await context.map.removePolyline('patrol-route');
```

---

## LocationService (`context.location`)

Access to device GPS location.

### `getCurrentLocation()`

```dart
Future<LatLng?> getCurrentLocation()
```

**Description:** Returns the device's current GPS location. Returns `null` if location services are unavailable or permission is denied.

**Returns:** `Future<LatLng?>` -- the current coordinate, or `null`.

**Example:**

```dart
final loc = await context.location.getCurrentLocation();
if (loc != null) {
  print('Current position: ${loc.latitude}, ${loc.longitude}');
}
```

---

## SpeechService (`context.speech`)

Access to user input features.

### `dictate()`

```dart
Future<String?> dictate()
```

**Description:** Starts native speech-to-text dictation via the platform recognizer. Returns the recognized text, or `null` if the user cancels or no speech is detected.

**Returns:** `Future<String?>` -- recognized text, or `null`.

**Example:**

```dart
final text = await context.speech.dictate();
if (text != null) {
  _descriptionController.text += ' $text';
}
```

---

## StorageService (`context.storage`)

Persistent per-extension key-value storage. Values are always strings -- serialize complex data as JSON.

### `read()`

```dart
Future<String?> read(String key)
```

**Description:** Reads a value from persistent storage. Returns `null` if the key does not exist.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | `String` | Yes | The storage key to read. |

**Returns:** `Future<String?>` -- the stored value, or `null`.

**Example:**

```dart
final draft = await context.storage.read('draft_title');
if (draft != null) {
  _titleController.text = draft;
}
```

---

### `write()`

```dart
Future<void> write(String key, String value)
```

**Description:** Writes a string value to persistent storage. Overwrites any existing value for the key.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | `String` | Yes | The storage key. |
| `value` | `String` | Yes | The value to store. |

**Returns:** `Future<void>`

**Example:**

```dart
await context.storage.write('draft_title', _titleController.text);
```

---

### `delete()`

```dart
Future<void> delete(String key)
```

**Description:** Deletes a key from storage. No-op if the key does not exist.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | `String` | Yes | The storage key to delete. |

**Returns:** `Future<void>`

**Example:**

```dart
await context.storage.delete('draft_title');
await context.storage.delete('draft_desc');
```

---

## MessagingService (`context.messaging`)

Access to contacts, peer discovery, and peer-to-peer messaging. Devices discover each other automatically via UDP broadcast on the local network -- no server or configuration required.

### `getPeers()`

```dart
Future<List<Peer>> getPeers()
```

**Description:** Returns a list of all known peers on the network.

**Returns:** `Future<List<Peer>>`

**Example:**

```dart
final peers = await context.messaging.getPeers();
for (final peer in peers) {
  print('${peer.callsign} (${peer.deviceId}) — ${peer.isOnline ? "online" : "offline"}');
}
```

---

### `onPeersChanged`

```dart
Stream<List<Peer>> get onPeersChanged
```

**Description:** A stream that fires whenever the peer list changes (peers come online, go offline, or update).

**Returns:** `Stream<List<Peer>>`

**Example:**

```dart
context.messaging.onPeersChanged.listen((peers) {
  setState(() => _peers = peers);
});
```

---

### `pickRecipients()`

```dart
Future<List<Peer>?> pickRecipients()
```

**Description:** Opens the host app's built-in contact picker UI, allowing the user to select one or more recipients. Returns `null` if the user cancels.

**Returns:** `Future<List<Peer>?>` -- the selected peers, or `null` on cancellation.

**Example:**

```dart
final selected = await context.messaging.pickRecipients();
if (selected != null) {
  for (final peer in selected) {
    print('Selected: ${peer.callsign}');
  }
}
```

---

### `send()`

```dart
Future<DeliveryReport> send(String peerId, String payload)
```

**Description:** Sends a message payload to a single peer.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `peerId` | `String` | Yes | The target peer's `deviceId`. |
| `payload` | `String` | Yes | The message payload (typically JSON-encoded). |

**Returns:** `Future<DeliveryReport>`

**Example:**

```dart
final report = await context.messaging.send(peer.deviceId, jsonEncode({
  'type': 'field_report',
  'title': 'Bridge Status',
  'description': 'Bridge is intact and passable.',
}));

if (report.successCount > 0) {
  print('Delivered!');
} else {
  print('Failed: ${report.results.first.error}');
}
```

---

### `sendToMultiple()`

```dart
Future<DeliveryReport> sendToMultiple(List<String> peerIds, String payload)
```

**Description:** Sends a message payload to multiple peers.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `peerIds` | `List<String>` | Yes | List of target peer `deviceId` values. |
| `payload` | `String` | Yes | The message payload. |

**Returns:** `Future<DeliveryReport>`

**Example:**

```dart
final peerIds = selectedPeers.map((p) => p.deviceId).toList();
final report = await context.messaging.sendToMultiple(peerIds, payload);
print('${report.successCount} delivered, ${report.failureCount} failed');
```

---

### `sendToGroup()`

```dart
Future<DeliveryReport> sendToGroup(String groupId, String payload)
```

**Description:** Sends a message payload to all members of a contact group.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | `String` | Yes | The group's `id`. |
| `payload` | `String` | Yes | The message payload. |

**Returns:** `Future<DeliveryReport>`

**Example:**

```dart
final report = await context.messaging.sendToGroup(groupId, payload);
print('${report.successCount} delivered to group');
```

---

### `broadcast()`

```dart
Future<DeliveryReport> broadcast(String payload)
```

**Description:** Broadcasts a message payload to all known peers on the network.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `payload` | `String` | Yes | The message payload. |

**Returns:** `Future<DeliveryReport>`

**Example:**

```dart
final report = await context.messaging.broadcast(jsonEncode({
  'type': 'alert',
  'message': 'All units fall back to rally point.',
}));
```

---

### `onMessageReceived`

```dart
Stream<IncomingMessage> get onMessageReceived
```

**Description:** A stream that emits incoming data messages from other peers. Messages are queued by the host -- if your extension is not active when a message arrives, it will be delivered when the extension next opens.

**Returns:** `Stream<IncomingMessage>`

**Example:**

```dart
context.messaging.onMessageReceived.listen((message) {
  final data = jsonDecode(message.payload) as Map<String, dynamic>;
  final type = data['type'] as String;

  switch (type) {
    case 'field_report':
      _handleFieldReport(message, data);
      break;
    case 'chat_message':
      _handleChatMessage(message, data);
      break;
  }
});
```

---

### `getUnreadCount()`

```dart
Future<int> getUnreadCount()
```

**Description:** Returns the number of unread messages for this extension.

**Returns:** `Future<int>`

**Example:**

```dart
final count = await context.messaging.getUnreadCount();
if (count > 0) {
  print('You have $count unread messages');
}
```

---

### `markAsRead()`

```dart
Future<void> markAsRead(String messageId)
```

**Description:** Marks a specific message as read.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `messageId` | `String` | Yes | The `id` from an `IncomingMessage`. |

**Returns:** `Future<void>`

**Example:**

```dart
await context.messaging.markAsRead(message.id);
```

---

### `markAllAsRead()`

```dart
Future<void> markAllAsRead()
```

**Description:** Marks all messages as read. Best practice: call this in your widget's `initState()` to clear the unread badge when the user opens your extension.

**Returns:** `Future<void>`

**Example:**

```dart
@override
void initState() {
  super.initState();
  widget.context.messaging.markAllAsRead();
}
```

---

### `getGroups()`

```dart
Future<List<ContactGroup>> getGroups()
```

**Description:** Returns all contact groups. Groups are managed by the host app -- extensions can read groups and send to them, but cannot create or modify groups.

**Returns:** `Future<List<ContactGroup>>`

**Example:**

```dart
final groups = await context.messaging.getGroups();
for (final group in groups) {
  print('${group.name}: ${group.memberDeviceIds.length} members');
}
```

---

## EntityService (`context.entities`)

Access to Lattice entity data — create, read, search, and stream entities.

### `publishEntity()`

```dart
Future<PublishEntityResult> publishEntity(PublishEntityRequest request)
```

**Description:** Publishes (creates or updates) an entity via the backend.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `request` | `PublishEntityRequest` | Yes | The entity publish request. |

**Returns:** `Future<PublishEntityResult>` — contains `entityId` and `displayName`.

**Example:**

```dart
final result = await context.entities.publishEntity(PublishEntityRequest(
  lat: 33.7490,
  lon: -84.3880,
  name: 'Observation Post',
  disposition: Disposition.friendly,
));
print('Published entity: ${result.entityId}');
```

---

### `getEntity()`

```dart
Future<Entity?> getEntity(String entityId)
```

**Description:** Gets a single entity by ID. Returns `null` if not found.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `entityId` | `String` | Yes | The entity's unique ID. |

**Returns:** `Future<Entity?>`

---

### `getEntities()`

```dart
Future<List<Entity>> getEntities()
```

**Description:** Returns all entities currently in the repository.

**Returns:** `Future<List<Entity>>`

**Example:**

```dart
final entities = await context.entities.getEntities();
for (final e in entities) {
  print('${e.name} (${e.disposition.name}) at ${e.lat}, ${e.lon}');
}
```

---

### `searchEntities()`

```dart
Future<List<Entity>> searchEntities(String query)
```

**Description:** Searches entities by name substring (case-insensitive).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `String` | Yes | Search string to match against entity names. |

**Returns:** `Future<List<Entity>>`

---

### `getNearbyEntities()`

```dart
Future<List<Entity>> getNearbyEntities(double lat, double lon, double radiusMeters)
```

**Description:** Finds entities within a radius of a point (haversine distance).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `lat` | `double` | Yes | Latitude of the center point. |
| `lon` | `double` | Yes | Longitude of the center point. |
| `radiusMeters` | `double` | Yes | Search radius in meters. |

**Returns:** `Future<List<Entity>>`

---

### `upsertEntity()`

```dart
Future<String> upsertEntity(Entity entity)
```

**Description:** Creates or updates an entity using a full `Entity` object. Returns the entity ID assigned by the backend.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `entity` | `Entity` | Yes | The full entity object to create or update. |

**Returns:** `Future<String>` — the entity ID.

---

### `streamEntityComponents()`

```dart
Stream<EntityEvent> streamEntityComponents()
```

**Description:** Streams entity component updates (upserts and deletes) from the backend. Each event is either an `EntityUpsert` (containing the full `Entity`) or an `EntityDelete` (containing the `entityId`).

**Returns:** `Stream<EntityEvent>`

**Example:**

```dart
context.entities.streamEntityComponents().listen((event) {
  switch (event) {
    case EntityUpsert(:final entity):
      print('Upserted: ${entity.name}');
    case EntityDelete(:final entityId):
      print('Deleted: $entityId');
  }
});
```

---

## TaskService (`context.tasks`)

Access to Lattice task creation, status management, and agent task listening.

### `createTask()`

```dart
Future<TaskData> createTask(CreateTaskParams params)
```

**Description:** Creates a new task.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `params` | `CreateTaskParams` | Yes | Task creation parameters. |

**Returns:** `Future<TaskData>`

**Example:**

```dart
final task = await context.tasks.createTask(CreateTaskParams(
  specificationTypeUrl: 'type.googleapis.com/my.TaskSpec',
  specificationBytes: utf8.encode(jsonEncode({'target': 'bridge'})),
  description: 'Inspect bridge structural integrity',
  assigneeEntityId: 'entity-123',
));
print('Created task: ${task.taskId}, status: ${task.statusLabel}');
```

---

### `getTask()`

```dart
Future<TaskData?> getTask(String taskId)
```

**Description:** Gets a single task by ID. Returns `null` if not found.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `taskId` | `String` | Yes | The task's unique ID. |

**Returns:** `Future<TaskData?>`

---

### `updateStatus()`

```dart
Future<TaskData> updateStatus(String taskId, int newRawStatus, {String? errorMessage, int? errorCode})
```

**Description:** Updates the status of a task.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `taskId` | `String` | Yes | The task's unique ID. |
| `newRawStatus` | `int` | Yes | The new raw status code (see `TaskData` status codes). |
| `errorMessage` | `String?` | No | Error message (for failure statuses). |
| `errorCode` | `int?` | No | Error code (for failure statuses). |

**Returns:** `Future<TaskData>`

**Example:**

```dart
// Accept and start executing
await context.tasks.updateStatus(task.taskId, 6); // WILCO
await context.tasks.updateStatus(task.taskId, 7); // EXECUTING

// Complete successfully
await context.tasks.updateStatus(task.taskId, 9); // DONE_OK
```

---

### `cancelTask()`

```dart
Future<TaskData> cancelTask(String taskId, {String? reason})
```

**Description:** Cancels a task. Internally sets the status to `DONE_NOT_OK` (raw status 10).

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `taskId` | `String` | Yes | The task's unique ID. |
| `reason` | `String?` | No | Optional cancellation reason (stored as `errorMessage`). |

**Returns:** `Future<TaskData>`

---

### `queryTasks()`

```dart
Future<List<TaskData>> queryTasks({
  String? assigneeEntityId,
  String? authorUserId,
  List<TaskStatusGroup>? statusGroups,
  String? specTypeUrl,
})
```

**Description:** Queries tasks with optional filters. All filters are combined with AND logic.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `assigneeEntityId` | `String?` | No | Filter by assignee entity ID. |
| `authorUserId` | `String?` | No | Filter by author user ID. |
| `statusGroups` | `List<TaskStatusGroup>?` | No | Filter by status group(s). |
| `specTypeUrl` | `String?` | No | Filter by specification type URL. |

**Returns:** `Future<List<TaskData>>`

**Example:**

```dart
final activeTasks = await context.tasks.queryTasks(
  statusGroups: [TaskStatusGroup.active],
  assigneeEntityId: 'entity-123',
);
```

---

### `listenAsAgent()`

```dart
Stream<TaskData> listenAsAgent()
```

**Description:** Listens for task assignments directed to this agent. Returns a stream of `TaskData` objects as new tasks are assigned.

**Returns:** `Stream<TaskData>`

---

## Types

### `LatLng`

A geographic coordinate. Supports value equality (`==` and `hashCode`) and JSON serialization.

```dart
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson();
  factory LatLng.fromJson(Map<String, dynamic> json);

  // Value equality: two LatLng with the same coordinates are equal.
}
```

---

### `HostInfo`

Information about the host environment.

```dart
class HostInfo {
  final String host;         // e.g. 'lattice-edge'
  final String version;      // e.g. '1.0.0'
  final String extensionId;  // ID of the calling extension
}
```

---

### `ExtensionDisplayMode`

Display mode for an extension's content.

```dart
enum ExtensionDisplayMode { panel, overlay }
```

| Value | Description |
|-------|-------------|
| `panel` | Extension appears as a side panel alongside the map. |
| `overlay` | Extension appears as a floating overlay tab. |

---

### `Peer`

Represents a peer device on the network.

```dart
class Peer {
  final String deviceId;    // Unique device identifier
  final String callsign;    // Human-readable name (e.g., "ALPHA-1")
  final String ip;          // IP address on the local network
  final bool isOnline;      // Currently reachable
  final DateTime lastSeen;  // Last heartbeat timestamp
}
```

---

### `ContactGroup`

A named group of contacts.

```dart
class ContactGroup {
  final String id;                        // Unique group identifier
  final String name;                      // Human-readable group name
  final List<String> memberDeviceIds;     // Device IDs of group members
}
```

---

### `IncomingMessage`

An incoming message from another peer.

```dart
class IncomingMessage {
  final String id;            // Unique message ID (for marking as read)
  final String fromPeerId;    // Sender's device ID
  final String fromCallsign;  // Sender's callsign
  final String payload;       // Message payload (your JSON string)
  final DateTime receivedAt;  // When the message was received
}
```

---

### `DeliveryResult`

The result of delivering a message to a single peer.

```dart
class DeliveryResult {
  final String peerId;   // Target peer's device ID
  final bool success;    // Whether delivery succeeded
  final String? error;   // Error message if success == false
}
```

---

### `DeliveryReport`

Aggregated delivery report for a multi-recipient send.

```dart
class DeliveryReport {
  final List<DeliveryResult> results;
  int get successCount;   // Number of successful deliveries
  int get failureCount;   // Number of failed deliveries
}
```

---

### `MapMarker`

A marker placed on the map by an extension.

```dart
class MapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String? label;
  final String? color;
  final MarkerIcon? icon;
  final MarkerDisposition? disposition;
}
```

---

### `MarkerIcon`

Built-in icon types for map markers.

```dart
enum MarkerIcon {
  air, ground, sea, helicopter, uav, fighter, bomber, tank,
  missile, submarine, satellite, sensor, radar, person,
  vehicle, building, signal, unknown
}
```

---

### `MarkerDisposition`

Military disposition for icon marker coloring.

```dart
enum MarkerDisposition {
  hostile, friendly, neutral, unknown
}
```

---

### `Entity`

A Lattice entity with position, disposition, and optional metadata.

```dart
class Entity {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final Disposition disposition;        // friendly, hostile, neutral, suspicious, unknown
  final ShapeType shapeType;            // point (default), polygon, line, ellipse
  final String? color;
  final String? symbol;
  final Map<String, dynamic>? extra;
  final List<String> taskCatalog;
  final String? description;
  final String? environment;
  final EntityOntology? ontology;
  final EntityProvenance? provenance;
  final EntityStatus? status;
  final List<AlternateId> alternateIds;
  final DateTime? expiryTime;
  final DateTime? createdTime;
  final bool? isLive;
  final Map<String, dynamic>? routeDetails;

  String get resolvedColor;   // color ?? disposition.defaultColor
  String get resolvedSymbol;  // symbol ?? disposition.defaultSymbol

  Entity copyWith({...});
}
```

---

### `Disposition`

Entity disposition with default color and symbol mappings.

```dart
enum Disposition {
  friendly,   // #4A90D9, circle
  hostile,    // #D94A4A, diamond
  neutral,    // #4AD94A, square
  suspicious, // #D9884A, diamond
  unknown     // #888888, circle
}
```

---

### `EntityEvent`

Sealed class for entity streaming events.

```dart
sealed class EntityEvent {}
class EntityUpsert extends EntityEvent { final Entity entity; }
class EntityDelete extends EntityEvent { final String entityId; }
```

---

### `PublishEntityRequest`

Request object for publishing an entity.

```dart
class PublishEntityRequest {
  final double lat;
  final double lon;
  final String? name;
  final Disposition disposition;   // default: Disposition.hostile
  final String environment;        // default: 'land'
  final String? sidc;              // MIL-STD-2525C SIDC string
}
```

---

### `PublishEntityResult`

Result of a successful entity publish.

```dart
class PublishEntityResult {
  final String entityId;
  final String displayName;
}
```

---

### `TaskData`

A Lattice task with status tracking and history.

```dart
class TaskData {
  final String taskId;
  final String specificationTypeUrl;
  final List<int> specificationBytes;
  final TaskStatusGroup statusGroup;
  final int rawStatus;
  final String statusLabel;
  final DateTime createTime;
  final DateTime lastUpdateTime;
  final String description;
  final List<TaskEntityData> initialEntities;
  final String? assigneeEntityId;
  final String? authorUserId;
  final String? parentTaskId;
  final String? errorMessage;
  final int? errorCode;
  final List<TaskEvent> statusHistory;

  bool get isTerminal;
  bool get isPending;
  bool get isActive;
  bool get isWilco;           // rawStatus == 6
}
```

**Raw status codes:**

| Code | Label | Group |
|------|-------|-------|
| 1 | Created | pending |
| 2 | Scheduled | pending |
| 3 | Sent | pending |
| 4 | Acknowledged (Machine) | pending |
| 5 | Acknowledged | pending |
| 6 | Will Comply | pending |
| 7 | Executing | active |
| 8 | Waiting for Update | active |
| 9 | Completed | terminal |
| 10 | Failed | terminal |
| 11 | Replaced | terminal |
| 12 | Cancel Requested | pending |
| 13 | Complete Requested | pending |
| 14 | Rejected | terminal |
| 15 | Paused | active |

---

### `TaskStatusGroup`

Grouping of task statuses.

```dart
enum TaskStatusGroup {
  pending,   // Created, Scheduled, Sent, Acknowledged, Will Comply, Cancel/Complete Requested
  active,    // Executing, Waiting for Update, Paused
  terminal   // Completed, Failed, Replaced, Rejected
}
```

---

### `CreateTaskParams`

Parameters for creating a new task.

```dart
class CreateTaskParams {
  final String specificationTypeUrl;
  final List<int> specificationBytes;
  final String description;
  final String? assigneeEntityId;
  final String? parentTaskId;
  final List<TaskEntityData> initialEntities;  // default: []
}
```

---

### `TaskEntityData`

Entity reference attached to a task.

```dart
class TaskEntityData {
  final String entityId;
  final String? displayName;
  final double? latitude;
  final double? longitude;
  final bool isSnapshot;  // default: false
}
```

---

### `TaskEvent`

A status change event in a task's history.

```dart
class TaskEvent {
  final DateTime timestamp;
  final int rawStatus;
  final String statusLabel;
}
```

---

## Error Contract

- **User cancellation** returns `null` (location pick dismissed, speech cancelled, recipient picker cancelled). Never throws.
- **Platform errors** throw exceptions (speech recognizer unavailable, storage write failure).
- **In web mode**, the JS bridge wraps all calls in try/catch. Errors serialize as `{error: "message"}` and the SDK rejects the corresponding `Future`.
- Never check for error envelopes like `{success: false}`. Use standard Dart try/catch.

---

## Storage Notes

- Values are always strings. Serialize complex data as JSON.
- Storage is namespaced per extension (`extension_storage:{extensionId}:{key}`). Extensions cannot access each other's data.
- Data persists across app restarts (backed by `SharedPreferences`).
- There is no per-extension quota. The practical limit is approximately 1 MB across all SharedPreferences on Android.

---

## Payload Design (Contacts)

Messages carry a `String` payload. Best practices:

- **JSON-encode your data** -- `jsonEncode({'type': 'report', ...})`
- **Include a `type` field** -- so the receiver can route different message types
- **Keep payloads under 10 MB** -- this is the transport limit
- **Don't send binary data** -- encode as base64 strings if needed, but prefer small payloads

Example payload structure:

```dart
final payload = jsonEncode({
  'type': 'field_report',       // Message type for routing
  'version': 1,                 // Schema version for forward compatibility
  'title': 'Bridge Status',
  'description': 'Intact and passable',
  'location': {'lat': 33.749, 'lng': -84.388},
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
```
