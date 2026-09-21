import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'ai_service.dart';
import 'object_service.dart';
import 'peripheral_services.dart';
import 'services.dart';
import 'extension_context.dart';
import 'types.dart';
import 'ui_service.dart';

/// Stub implementation of [ExtensionContext] for standalone preview mode.
/// Returns sensible defaults: a fake location, no-op speech, in-memory storage.
class StubExtensionContext implements ExtensionContext {
  @override
  HostInfo get hostInfo => const HostInfo(
        host: 'standalone',
        version: '0.0.0',
        extensionId: 'preview',
        callsign: 'CALLSIGN-01',
      );

  late final MapService _map = _StubMapService();
  late final LocationService _location = _StubLocationService();
  late final SpeechService _speech = _StubSpeechService();
  late final StorageService _storage = _StubStorageService();
  late final MessagingService _messaging = StubMessagingService();
  late final EntityService _entities = _StubEntityService();
  late final TaskService _tasks = _StubTaskService();
  late final UiService _ui = _StubUiService();
  late final AiService _ai = _StubAiService();
  late final MeshItemStoreService _meshItemStore = _StubMeshItemStoreService();
  late final ObjectService _objects = _StubObjectService();
  late final DeviceService _device = _StubDeviceService();
  late final PeripheralsService _peripherals = _StubPeripheralsService();
  late final NetworkService _network = _StubNetworkService();

  @override
  MapService get map => _map;

  @override
  LocationService get location => _location;

  @override
  SpeechService get speech => _speech;

  @override
  StorageService get storage => _storage;

  @override
  MessagingService get messaging => _messaging;

  @override
  EntityService get entities => _entities;

  @override
  TaskService get tasks => _tasks;

  @override
  UiService get ui => _ui;

  @override
  AiService get ai => _ai;

  @override
  MeshItemStoreService get meshItemStore => _meshItemStore;

  @override
  ObjectService get objects => _objects;

  @override
  DeviceService get device => _device;

  @override
  PeripheralsService get peripherals => _peripherals;

  @override
  NetworkService get network => _network;

  @override
  void close() {}

  /// Factory matching [WebExtensionContext.connect] signature.
  /// Used by the conditional import so both sides expose the same API.
  static Future<StubExtensionContext> connect({
    required Duration timeout,
  }) async =>
      StubExtensionContext();
}

class _StubMapService implements MapService {
  static const _baseLat = 33.69377185495327;
  static const _baseLng = -117.91658086952512;
  static const _latRange = 0.009;
  static const _lngRange = 0.0108;
  final _random = math.Random();
  int _nextId = 0;
  final List<MapMarker> _markers = [];

  @override
  Future<LatLng?> pickLocation() async {
    final lat = _baseLat + (_random.nextDouble() * 2 - 1) * _latRange;
    final lng = _baseLng + (_random.nextDouble() * 2 - 1) * _lngRange;
    return LatLng(lat, lng);
  }

  @override
  Future<List<LatLng>?> drawPolygon({
    String? previewStrokeColor,
    String? previewFillColor,
    String? toolbarHint,
  }) async {
    // drawPolygon not supported in standalone — host required for map interaction.
    return null;
  }

  @override
  Future<List<LatLng>?> drawPolyline({
    String? previewColor,
    double? previewWidth,
    String? toolbarHint,
  }) async {
    // drawPolyline not supported in standalone — host required for map interaction.
    return null;
  }

  @override
  Future<String> addMarker(LatLng location,
      {String? label,
      String? color,
      MarkerIcon? icon,
      MarkerDisposition? disposition}) async {
    final id = 'stub_${_nextId++}';
    _markers.add(MapMarker(
      id: id,
      latitude: location.latitude,
      longitude: location.longitude,
      label: label,
      color: color,
      icon: icon,
      disposition: disposition,
    ));
    return id;
  }

  @override
  Future<void> removeMarker(String id) async {
    _markers.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<MapMarker>> getMarkers() async => List.unmodifiable(_markers);

  @override
  Future<void> clearMarkers() async => _markers.clear();

  @override
  Future<void> addPolyline(String id, List<LatLng> points,
      {String? color,
      double? width,
      List<double>? dashPattern,
      double? opacity}) async {}

  @override
  Future<void> removePolyline(String id) async {}

  @override
  Future<void> clearPolylines() async {}

  @override
  Future<void> addPolygon(String id, List<LatLng> points,
      {String? strokeColor, String? fillColor}) async {}

  @override
  Future<void> updatePolygon(String id, List<LatLng> points,
      {String? strokeColor, String? fillColor}) async {}

  @override
  Future<void> removePolygon(String id) async {}

  @override
  Future<void> addTacticalGraphic(String id, String sidc, List<LatLng> points,
      {Map<String, String>? modifiers}) async {}

  @override
  Future<void> updateTacticalGraphic(String id,
      {String? sidc,
      List<LatLng>? points,
      Map<String, String>? modifiers}) async {}

  @override
  Future<void> removeTacticalGraphic(String id) async {}

  @override
  Future<void> flyTo(LatLng location, {double? zoom}) async {}

  @override
  Future<ScreenPoint?> getPixelFromLocation(LatLng location) async => null;
  @override
  Future<bool> simulateMarkerTap(String entityId) async => false;
  @override
  Future<Uint8List?> captureMap({
    List<LatLng>? quad,
    List<String>? columnLabels,
    List<String>? rowLabels,
  }) async =>
      null;
}

class _StubLocationService implements LocationService {
  @override
  Future<LatLng?> getCurrentLocation() async =>
      const LatLng(33.69377185495327, -117.91658086952512);
}

class _StubSpeechService implements SpeechService {
  @override
  Future<String?> dictate() async => null;
}

class _StubStorageService implements StorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _StubEntityService implements EntityService {
  final List<Entity> _entities = [
    const Entity(
      id: 'stub-friendly-1',
      name: 'Alpha Team',
      lat: 33.6938,
      lon: -117.9166,
      disposition: Disposition.friendly,
    ),
    const Entity(
      id: 'stub-hostile-1',
      name: 'Hostile Contact',
      lat: 33.6950,
      lon: -117.9180,
      disposition: Disposition.hostile,
    ),
    const Entity(
      id: 'stub-neutral-1',
      name: 'Neutral Observer',
      lat: 33.6920,
      lon: -117.9140,
      disposition: Disposition.neutral,
    ),
  ];

  @override
  Future<List<Entity>> getEntities() async => List.unmodifiable(_entities);

  @override
  Future<Entity?> getEntity(String entityId) async =>
      _entities.where((e) => e.id == entityId).firstOrNull;

  @override
  Future<List<Entity>> searchEntities(String query) async {
    final lower = query.toLowerCase();
    return _entities
        .where((e) => e.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<List<Entity>> getNearbyEntities(
          double lat, double lon, double radiusMeters) async =>
      List.unmodifiable(_entities);

  @override
  Future<PublishEntityResult> publishEntity(
      PublishEntityRequest request) async {
    final id = 'stub-${DateTime.now().millisecondsSinceEpoch}';
    final entity = Entity(
      id: id,
      name: request.name ?? 'New Entity',
      lat: request.lat,
      lon: request.lon,
      disposition: request.disposition,
    );
    _entities.add(entity);
    return PublishEntityResult(entityId: id, displayName: entity.name);
  }

  @override
  Future<String> upsertEntity(Entity entity) async {
    _entities.removeWhere((e) => e.id == entity.id);
    _entities.add(entity);
    return entity.id;
  }

  @override
  Future<void> deleteEntity(String entityId) async {
    _entities.removeWhere((e) => e.id == entityId);
  }

  @override
  Stream<EntityEvent> streamEntityComponents() => const Stream.empty();
}

class _StubTaskService implements TaskService {
  final Map<String, TaskData> _tasks = {};
  int _nextId = 1;

  @override
  Future<TaskData> createTask(CreateTaskParams params) async {
    final taskId = 'stub-task-${_nextId++}';
    final task = TaskData(
      taskId: taskId,
      specificationTypeUrl: params.specificationTypeUrl,
      specificationBytes: params.specificationBytes,
      statusGroup: TaskStatusGroup.pending,
      rawStatus: 1,
      statusLabel: 'Created',
      description: params.description,
      assigneeEntityId: params.assigneeEntityId,
      parentTaskId: params.parentTaskId,
      initialEntities: params.initialEntities,
      createTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
    );
    _tasks[taskId] = task;
    return task;
  }

  @override
  Future<TaskData?> getTask(String taskId) async => _tasks[taskId];

  @override
  Future<List<TaskData>> queryTasks({
    String? assigneeEntityId,
    String? authorUserId,
    List<TaskStatusGroup>? statusGroups,
    String? specTypeUrl,
  }) async {
    return _tasks.values.where((t) {
      if (assigneeEntityId != null && t.assigneeEntityId != assigneeEntityId) {
        return false;
      }
      if (authorUserId != null && t.authorUserId != authorUserId) return false;
      if (statusGroups != null && !statusGroups.contains(t.statusGroup)) {
        return false;
      }
      if (specTypeUrl != null && t.specificationTypeUrl != specTypeUrl) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<TaskData> updateStatus(String taskId, int newRawStatus,
      {String? errorMessage, int? errorCode}) async {
    final existing = _tasks[taskId];
    if (existing == null) throw Exception('Task not found: $taskId');
    final resolvedErrorCode = errorCode ?? existing.errorCode;
    final updated = TaskData(
      taskId: existing.taskId,
      specificationTypeUrl: existing.specificationTypeUrl,
      specificationBytes: existing.specificationBytes,
      statusGroup: TaskData.statusGroupFromRawStatus(newRawStatus),
      rawStatus: newRawStatus,
      statusLabel:
          TaskData.statusLabelFromStatus(newRawStatus, resolvedErrorCode),
      description: existing.description,
      assigneeEntityId: existing.assigneeEntityId,
      authorUserId: existing.authorUserId,
      parentTaskId: existing.parentTaskId,
      initialEntities: existing.initialEntities,
      createTime: existing.createTime,
      lastUpdateTime: DateTime.now(),
      errorMessage: errorMessage ?? existing.errorMessage,
      errorCode: resolvedErrorCode,
    );
    _tasks[taskId] = updated;
    return updated;
  }

  @override
  Future<TaskData> cancelTask(String taskId, {String? reason}) async {
    return updateStatus(taskId, 10, errorMessage: reason);
  }

  @override
  Stream<TaskData> listenAsAgent() => const Stream.empty();
}

/// Stub implementation of [MessagingService] with no-op/empty defaults.
class StubMessagingService implements MessagingService {
  final StreamController<IncomingMessage> _messageController =
      StreamController<IncomingMessage>.broadcast();

  @override
  Future<List<Peer>> getPeers() async => [];

  @override
  Stream<List<Peer>> get onPeersChanged => const Stream.empty();

  @override
  Future<List<Peer>?> pickRecipients() async => null;

  @override
  Future<DeliveryReport> send(String peerId, String payload) async =>
      const DeliveryReport(results: []);

  @override
  Future<DeliveryReport> sendToMultiple(
          List<String> peerIds, String payload) async =>
      DeliveryReport(
        results: peerIds
            .map((id) =>
                DeliveryResult(peerId: id, success: false, error: 'stub'))
            .toList(),
      );

  @override
  Future<DeliveryReport> sendToGroup(String groupId, String payload) async =>
      const DeliveryReport(results: []);

  @override
  Future<DeliveryReport> broadcast(String payload) async =>
      const DeliveryReport(results: []);

  @override
  Stream<IncomingMessage> get onMessageReceived => _messageController.stream;

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<void> markAsRead(String messageId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<List<ContactGroup>> getGroups() async => [];
}

class _StubUiService implements UiService {
  String _activeView = 'map';
  String? _activePanel;
  String? _activeExtension;

  @override
  Future<void> navigateTo(String viewId) async => _activeView = viewId;

  @override
  Future<String> getActiveView() async => _activeView;

  @override
  Future<void> openPanel(String panelId) async => _activePanel = panelId;

  @override
  Future<void> closePanel() async => _activePanel = null;

  @override
  Future<String?> getActivePanel() async => _activePanel;

  @override
  Future<void> openExtension(String extensionId) async =>
      _activeExtension = extensionId;

  @override
  Future<void> closeExtension(String extensionId) async {
    if (_activeExtension == extensionId) _activeExtension = null;
  }

  @override
  Future<String?> getActiveExtension() async => _activeExtension;

  @override
  Future<Map<String, dynamic>?> getLaunchArgs() async => null;

  @override
  Future<String?> debugReadCommand() async => null;

  @override
  Future<bool> isLocationPickerActive() async => false;

  @override
  Future<bool> isPttActive() async => false;

  @override
  Future<bool> isStatusBarEnabled() async => false;
  // Deprecated no-ops: the left sidebar was removed. Bodies exist only because
  // `implements UiService` does not inherit default bodies.
  @override
  Future<void> openLeftPanel(String panelId) async {}
  @override
  Future<void> closeLeftPanel() async {}
  @override
  Future<String?> getActiveLeftPanel() async => null;
  @override
  Future<void> showBanner(String message) async {}
  @override
  Future<void> hideBanner() async {}
  @override
  Future<void> showToast(String message,
      {String type = 'info', String priority = 'routine'}) async {}
  @override
  Future<void> setExtensionDisplayMode(String extensionId, String mode) async {}
  PanelSize _panelSize = PanelSize.small;
  @override
  Future<void> setPanelSize(PanelSize size) async => _panelSize = size;
  @override
  Future<PanelSize> getPanelSize() async => _panelSize;
  @override
  Future<void> resetUi() async {
    _activeView = 'map';
    _activePanel = null;
    _activeExtension = null;
    _manualLocationEnabled = false;
    _panelSize = PanelSize.small;
  }

  @override
  Future<void> hideKeyboard() async {}
  bool _manualLocationEnabled = false;
  @override
  Future<void> setManualLocation(double lat, double lon) async =>
      _manualLocationEnabled = true;
  @override
  Future<void> clearManualLocation() async => _manualLocationEnabled = false;
  @override
  Future<bool> isManualLocationEnabled() async => _manualLocationEnabled;
  @override
  Future<bool> tapWidget(Map<String, dynamic> selector) async => true;
  @override
  Future<void> tapAt(double x, double y) async {}
  @override
  Future<void> longPressAt(double x, double y, {int holdMs = 600}) async {}
  @override
  Future<bool> enterText(Map<String, dynamic> selector, String text) async =>
      true;
  @override
  Future<List<String>> getVisibleLabels() async => ['stub_label'];
  @override
  Future<Map<String, dynamic>?> waitForEvent(
    String type, {
    Map<String, dynamic>? match,
    int timeoutMs = 30000,
    int lookbackMs = 2500,
  }) async =>
      null;
}

class _StubAiService implements AiService {
  late final AiChatCompletions _chat = _StubAiChatCompletions();
  @override
  AiChatCompletions get chat => _chat;
  @override
  Future<void> clearHistory() async {}
}

class _StubAiChatCompletions implements AiChatCompletions {
  late final AiCompletions _completions = _StubAiCompletions();
  @override
  AiCompletions get completions => _completions;
}

class _StubAiCompletions implements AiCompletions {
  static const _stubResponse =
      'This is a simulated AI response. Connect to the Lattice host for real inference.';

  @override
  Stream<ChatCompletionChunk> createStream(
      ChatCompletionRequest request) async* {
    final id = 'stub-${DateTime.now().millisecondsSinceEpoch}';
    yield ChatCompletionChunk(id: id, choices: [
      const ChatChunkChoice(
          index: 0, delta: ChatCompletionDelta(role: 'assistant')),
    ]);
    final words = _stubResponse.split(' ');
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 50));
      yield ChatCompletionChunk(id: id, choices: [
        ChatChunkChoice(
            index: 0, delta: ChatCompletionDelta(content: '$word ')),
      ]);
    }
    yield ChatCompletionChunk(id: id, choices: [
      const ChatChunkChoice(
          index: 0, delta: ChatCompletionDelta(), finishReason: 'stop'),
    ]);
  }

  @override
  Future<ChatCompletion> create(ChatCompletionRequest request) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return ChatCompletion(
        id: 'stub-${DateTime.now().millisecondsSinceEpoch}',
        choices: [
          const ChatChoice(
              index: 0,
              message: ChatCompletionMessage(
                  role: 'assistant', content: _stubResponse),
              finishReason: 'stop'),
        ]);
  }
}

class _StubMeshItemStoreService implements MeshItemStoreService {
  @override
  late final MeshItemService items = _StubMeshItemService();

  @override
  late final MeshStreamService streams = _StubMeshStreamService();
}

class _StubMeshItemService implements MeshItemService {
  @override
  Future<List<MeshDataType>> listDataTypes() async => [];

  @override
  Future<MeshDataType?> getDataType(MeshDataTypePath path) async => null;

  @override
  Future<MeshItem> createItem(
    MeshDataTypePath type,
    Map<String, Object?> data, {
    Duration? ttl,
  }) async =>
      throw UnsupportedError('mesh-item-store not available in stub context');

  @override
  Future<MeshBatchResult<MeshItem>> createItems(
    MeshDataTypePath type,
    List<Map<String, Object?>> data, {
    Duration? ttl,
  }) async =>
      throw UnsupportedError('mesh-item-store not available in stub context');

  @override
  Future<MeshItem?> getItem(MeshItemPath path) async => null;

  @override
  Future<List<MeshItem>> listItems(
    MeshDataTypePath type, {
    Map<String, Object?>? filter,
  }) async =>
      [];

  @override
  Future<MeshItem> updateItem(
    MeshItemPath path,
    Map<String, Object?> data, {
    Duration? ttl,
  }) async =>
      throw UnsupportedError('mesh-item-store not available in stub context');

  @override
  Future<void> deleteItem(MeshItemPath path) async =>
      throw UnsupportedError('mesh-item-store not available in stub context');
}

class _StubMeshStreamService implements MeshStreamService {
  @override
  Future<List<MeshDataType>> listStreamDataTypes() async => [];

  @override
  Future<MeshDataType?> getStreamDataType(MeshDataTypePath path) async => null;

  @override
  Future<MeshBatchResult<DateTime>> publish(
    MeshDataTypePath type,
    List<Map<String, Object?>> messages,
  ) async =>
      throw UnsupportedError('mesh-item-store not available in stub context');

  @override
  Stream<MeshStreamMessage> subscribe(MeshDataTypePath type) =>
      const Stream.empty();
}

class _StubObjectService implements ObjectService {
  @override
  Future<ObjectUploadResult> upload(String path, Uint8List bytes,
          {String? contentType, Duration? ttl}) async =>
      ObjectUploadResult(path: path);

  @override
  Future<Uint8List?> download(String path) async => null;

  @override
  Future<List<ObjectMetadata>> list({String? prefix}) async => [];

  @override
  Future<void> delete(String path) async {}

  @override
  Future<ObjectMetadata?> getMetadata(String path) async => null;
}

class _StubUsbSerialService implements UsbSerialService {
  final _rxController = StreamController<Uint8List>.broadcast();
  final _eventController = StreamController<UsbSerialEvent>.broadcast();

  @override
  Stream<Uint8List> get rxBytes => _rxController.stream;

  @override
  Stream<UsbSerialEvent> get events => _eventController.stream;

  @override
  Future<String> connect({
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  }) async =>
      '{"success":false,"message":"USB serial not available in standalone mode"}';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<String> listDevices() async => '[]';

  @override
  void dispose() {
    _rxController.close();
    _eventController.close();
  }
}

class _StubDeviceService implements DeviceService {
  late final UsbSerialService _usbSerial = _StubUsbSerialService();

  @override
  UsbSerialService get usbSerial => _usbSerial;
}

class _StubRangeFinderService implements RangeFinderService {
  final _controller = StreamController<RangeFinderTarget>.broadcast();

  @override
  void publishTarget(RangeFinderTarget target) {
    _controller.add(target);
  }

  @override
  Stream<RangeFinderTarget> get targetStream => _controller.stream;
}

class _StubPeripheralsService implements PeripheralsService {
  late final RangeFinderService _rangeFinder = _StubRangeFinderService();

  @override
  RangeFinderService get rangeFinder => _rangeFinder;
}

class _StubUdpSubscription implements UdpSubscription {
  @override
  Stream<UdpDatagram> get datagrams => const Stream.empty();

  @override
  Future<SendResult> send(
    Uint8List bytes, {
    String? destinationIp,
    int? port,
  }) async =>
      const SendResult(success: false, error: 'stub');

  @override
  Future<void> close() async {}
}

class _StubNetworkService implements NetworkService {
  @override
  Future<UdpSubscription> subscribeMulticast(String group, int port) async =>
      _StubUdpSubscription();

  @override
  Future<UdpSubscription> subscribeUnicast(int port) async =>
      _StubUdpSubscription();

  @override
  Future<SendResult> sendMulticast(
    String group,
    int port,
    Uint8List bytes,
  ) async =>
      const SendResult(success: false, error: 'stub');

  @override
  Future<SendResult> sendUnicast(
    String destinationIp,
    int port,
    Uint8List bytes,
  ) async =>
      const SendResult(success: false, error: 'stub');
}

/// Alias so the conditional import in extension_context.dart can reference
/// `platform_impl.WebExtensionContext` on native targets without error.
typedef WebExtensionContext = StubExtensionContext;
