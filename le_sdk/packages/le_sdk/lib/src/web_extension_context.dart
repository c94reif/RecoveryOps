import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ai_service.dart';
import 'peripheral_services.dart';
import 'services.dart';
import 'extension_context.dart';
import 'types.dart';
import 'ui_service.dart';

/// Web implementation of [ExtensionContext] that wraps the
/// `window.LatticeEdgeExtension` JS bridge via dart:js_interop.
///
/// Used when the extension is built as a Flutter web app and loaded
/// in the host's WebView. Created via [ExtensionContext.connect()].
class WebExtensionContext implements ExtensionContext {
  final HostInfo _hostInfo;
  late final MapService _map;
  late final LocationService _location;
  late final SpeechService _speech;
  late final StorageService _storage;
  late final EntityService _entities;
  late final TaskService _tasks;
  late final UiService _ui;
  late final AiService _ai;
  // USB serial and peripherals are not available in web extensions.
  final DeviceService _device = _WebDeviceService();
  final PeripheralsService _peripherals = _WebPeripheralsService();

  WebExtensionContext._({required HostInfo hostInfo}) : _hostInfo = hostInfo;

  static Future<WebExtensionContext> connect({
    required Duration timeout,
  }) async {
    final bridge = await _waitForBridge(timeout);
    // Fetch host info during connect so getHostInfo() can be sync.
    // The JS bridge returns a Promise, so use the async call helper.
    final hostInfoJs = await _callBridge(bridge, 'getHostInfo');
    if (hostInfoJs == null) {
      throw StateError('getHostInfo returned null');
    }
    final hostInfo = HostInfo.fromJson(
      jsonDecode(hostInfoJs) as Map<String, dynamic>,
    );
    final ctx = WebExtensionContext._(hostInfo: hostInfo);
    ctx._map = _WebMapService(bridge);
    ctx._location = _WebLocationService(bridge);
    ctx._speech = _WebSpeechService(bridge);
    ctx._storage = _WebStorageService(bridge);
    ctx._messaging = _WebMessagingService(bridge);
    ctx._entities = _WebEntityService(bridge);
    ctx._tasks = _WebTaskService(bridge);
    ctx._ui = _WebUiService(bridge);
    ctx._ai = _WebAiService(bridge);
    return ctx;
  }

  static Future<JSObject> _waitForBridge(Duration timeout) {
    final completer = Completer<JSObject>();

    final existing = web.window.getProperty('LatticeEdgeExtension'.toJS);
    if (existing != null && existing.isA<JSObject>()) {
      return Future.value(existing as JSObject);
    }

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException(
          'LatticeEdgeExtension bridge not available — '
          'is this running inside Lattice Edge?',
          timeout,
        ));
      }
    });

    // Register the ready callback
    web.window.setProperty(
      '__LatticeEdgeExtension_onBridgeReady'.toJS,
      (() {
        timer.cancel();
        final bridge = web.window.getProperty('LatticeEdgeExtension'.toJS);
        if (!completer.isCompleted && bridge != null && bridge.isA<JSObject>()) {
          completer.complete(bridge as JSObject);
        }
      }).toJS,
    );

    return completer.future;
  }

  /// Call a bridge method and await the Promise result as a JSON string.
  ///
  /// The bridge JS `call()` function JSON.parse()s the handler result before
  /// resolving, so the Promise may resolve with a JS object rather than a
  /// string.  We handle both cases: if it's already a string we return it
  /// directly, otherwise we JSON.stringify it back into a Dart string.
  static Future<String?> _callBridge(
    JSObject bridge,
    String method, [
    List<String> args = const [],
  ]) async {
    final fn = bridge.getProperty(method.toJS);
    if (fn == null || !fn.isA<JSFunction>()) return null;
    final JSAny? jsResult;
    switch (args.length) {
      case 0:
        jsResult = (fn as JSFunction).callAsFunction(bridge);
      case 1:
        jsResult = (fn as JSFunction).callAsFunction(bridge, args[0].toJS);
      case 2:
        jsResult = (fn as JSFunction)
            .callAsFunction(bridge, args[0].toJS, args[1].toJS);
      default:
        jsResult = (fn as JSFunction).callAsFunction(bridge, args[0].toJS);
    }
    if (jsResult == null) return null;
    // The bridge returns Promises — cast to JSPromise and await
    final result = await (jsResult as JSPromise<JSAny?>).toDart;
    if (result == null) return null;
    // The bridge JS call() JSON.parse()s the result, so we may get a
    // JSObject (parsed JSON) or a JSString (plain text like speech result).
    if (result.isA<JSString>()) {
      return (result as JSString).toDart;
    }
    // Re-serialize JS object back to a JSON string for Dart consumption.
    final json = globalContext.getProperty('JSON'.toJS) as JSObject;
    final stringifyFn = json.getProperty('stringify'.toJS) as JSFunction;
    final jsonStr = stringifyFn.callAsFunction(json, result);
    if (jsonStr == null) return null;
    return (jsonStr as JSString).toDart;
  }

  /// Call a nested bridge method (e.g. 'map.pickLocation').
  static Future<String?> _callNestedBridge(
    JSObject bridge,
    String group,
    String method, [
    List<String> args = const [],
  ]) async {
    final groupObj = bridge.getProperty(group.toJS);
    if (groupObj == null || !groupObj.isA<JSObject>()) return null;
    return _callBridge(groupObj as JSObject, method, args);
  }

  @override
  HostInfo get hostInfo => _hostInfo;

  @override
  MapService get map => _map;

  @override
  LocationService get location => _location;

  @override
  SpeechService get speech => _speech;

  @override
  StorageService get storage => _storage;

  late final MessagingService _messaging;

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
  DeviceService get device => _device;

  @override
  PeripheralsService get peripherals => _peripherals;

  @override
  void close() {
    final bridge = web.window.getProperty('LatticeEdgeExtension'.toJS);
    if (bridge != null && bridge.isA<JSObject>()) {
      final fn = (bridge as JSObject).getProperty('close'.toJS);
      if (fn != null && fn.isA<JSFunction>()) {
        (fn as JSFunction).callAsFunction(bridge);
      }
    }
  }
}

class _WebMapService implements MapService {
  final JSObject _bridge;
  _WebMapService(this._bridge);

  @override
  Future<LatLng?> pickLocation() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'pickLocation',
    );
    if (result == null) return null;
    final data = jsonDecode(result);
    if (data == null) return null;
    final lat = (data['latitude'] ?? data['lat']) as num?;
    final lng = (data['longitude'] ?? data['lng']) as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  @override
  Future<String> addMarker(
    LatLng location, {
    String? label,
    String? color,
    MarkerIcon? icon,
    MarkerDisposition? disposition,
  }) async {
    final payload = jsonEncode({
      'latitude': location.latitude,
      'longitude': location.longitude,
      if (label != null) 'label': label,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon.name,
      if (disposition != null) 'disposition': disposition.name,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'addMarker', [payload],
    );
    if (result == null) return '';
    final data = jsonDecode(result);
    if (data is Map && data['id'] != null) return data['id'] as String;
    if (data is String) return data;
    return '';
  }

  @override
  Future<void> removeMarker(String id) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'removeMarker', [id],
    );
  }

  @override
  Future<List<MapMarker>> getMarkers() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'getMarkers',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List?;
    if (list == null) return [];
    return list.map((m) => MapMarker.fromJson(m as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> clearMarkers() async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'clearMarkers',
    );
  }

  @override
  Future<void> addPolyline(String id, List<LatLng> points, {String? color}) async {
    final payload = jsonEncode({
      'id': id,
      'points': points.map((p) => p.toJson()).toList(),
      if (color != null) 'color': color,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'addPolyline', [payload],
    );
  }

  @override
  Future<void> removePolyline(String id) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'removePolyline', [id],
    );
  }

  @override
  Future<void> clearPolylines() async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'clearPolylines',
    );
  }

  @override
  Future<void> flyTo(LatLng location, {double? zoom}) async {
    final payload = jsonEncode({
      'latitude': location.latitude,
      'longitude': location.longitude,
      if (zoom != null) 'zoom': zoom,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'flyTo', [payload],
    );
  }

  @override
  Future<ScreenPoint?> getPixelFromLocation(LatLng location) async {
    final payload = jsonEncode({
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'getPixelFromLocation', [payload],
    );
    if (result == null || result == 'null') return null;
    final data = jsonDecode(result.toString()) as Map<String, dynamic>;
    return ScreenPoint.fromJson(data);
  }

  @override
  Future<bool> simulateMarkerTap(String entityId) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'map', 'simulateMarkerTap', [jsonEncode({'entityId': entityId})],
    );
    return result == 'true' || result == '{"success":true}';
  }
}

class _WebLocationService implements LocationService {
  final JSObject _bridge;
  _WebLocationService(this._bridge);

  @override
  Future<LatLng?> getCurrentLocation() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'location', 'getCurrentLocation',
    );
    if (result == null) return null;
    final data = jsonDecode(result);
    if (data == null) return null;
    final lat = (data['lat'] ?? data['latitude']) as num?;
    final lng = (data['lon'] ?? data['longitude']) as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }
}

class _WebSpeechService implements SpeechService {
  final JSObject _bridge;
  _WebSpeechService(this._bridge);

  @override
  Future<String?> dictate() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'speech', 'dictate',
    );
    // Bridge returns the text string directly (not JSON-wrapped).
    // _callBridge already converts JSString → Dart String.
    return result;
  }
}

/// Stub fallback for web targets when the Lattice bridge is unavailable
/// (e.g. standalone preview in a browser). Mirrors the native
/// StubExtensionContext with sensible no-op defaults.
class StubExtensionContext implements ExtensionContext {
  @override
  HostInfo get hostInfo => const HostInfo(
        host: 'standalone-web',
        version: '0.0.0',
        extensionId: 'preview',
        callsign: 'CALLSIGN-01',
      );

  late final MapService _map = _StubWebMapService();
  late final LocationService _location = _StubWebLocationService();
  late final SpeechService _speech = _StubWebSpeechService();
  late final StorageService _storage = _StubWebStorageService();
  late final MessagingService _messaging = _StubWebMessagingService();
  late final EntityService _entities = _StubWebEntityService();
  late final TaskService _tasks = _StubWebTaskService();
  late final UiService _ui = _StubWebUiService();
  late final AiService _ai = _StubWebAiService();
  final DeviceService _device = _WebDeviceService();
  final PeripheralsService _peripherals = _WebPeripheralsService();

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
  DeviceService get device => _device;

  @override
  PeripheralsService get peripherals => _peripherals;

  @override
  void close() {}

  static Future<StubExtensionContext> connect({
    required Duration timeout,
  }) async =>
      StubExtensionContext();
}

class _StubWebLocationService implements LocationService {
  @override
  Future<LatLng?> getCurrentLocation() async =>
      const LatLng(33.69377185495327, -117.91658086952512);
}

class _StubWebMapService implements MapService {
  int _nextId = 0;
  @override
  Future<LatLng?> pickLocation() async => const LatLng(33.69377185495327, -117.91658086952512);
  @override
  Future<String> addMarker(LatLng location, {String? label, String? color, MarkerIcon? icon, MarkerDisposition? disposition}) async => 'stub_${_nextId++}';
  @override
  Future<void> removeMarker(String id) async {}
  @override
  Future<List<MapMarker>> getMarkers() async => [];
  @override
  Future<void> clearMarkers() async {}
  @override
  Future<void> addPolyline(String id, List<LatLng> points, {String? color}) async {}
  @override
  Future<void> removePolyline(String id) async {}
  @override
  Future<void> clearPolylines() async {}
  @override
  Future<void> flyTo(LatLng location, {double? zoom}) async {}
  @override
  Future<ScreenPoint?> getPixelFromLocation(LatLng location) async => null;
  @override
  Future<bool> simulateMarkerTap(String entityId) async => false;
}

class _StubWebSpeechService implements SpeechService {
  @override
  Future<String?> dictate() async => null;
}

class _StubWebStorageService implements StorageService {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _StubWebEntityService implements EntityService {
  @override
  Future<List<Entity>> getEntities() async => [];
  @override
  Future<Entity?> getEntity(String entityId) async => null;
  @override
  Future<List<Entity>> searchEntities(String query) async => [];
  @override
  Future<List<Entity>> getNearbyEntities(
          double lat, double lon, double radiusMeters) async =>
      [];
  @override
  Future<PublishEntityResult> publishEntity(
          PublishEntityRequest request) async =>
      PublishEntityResult(entityId: 'stub', displayName: 'Stub');
  @override
  Future<String> upsertEntity(Entity entity) async => entity.id;
  @override
  Stream<EntityEvent> streamEntityComponents() => const Stream.empty();
}

class _StubWebTaskService implements TaskService {
  @override
  Future<TaskData> createTask(CreateTaskParams params) async =>
      throw UnimplementedError('Stub');
  @override
  Future<TaskData?> getTask(String taskId) async => null;
  @override
  Future<List<TaskData>> queryTasks(
          {String? assigneeEntityId,
          String? authorUserId,
          List<TaskStatusGroup>? statusGroups,
          String? specTypeUrl}) async =>
      [];
  @override
  Future<TaskData> updateStatus(String taskId, int newRawStatus,
          {String? errorMessage, int? errorCode}) async =>
      throw UnimplementedError('Stub');
  @override
  Future<TaskData> cancelTask(String taskId, {String? reason}) async =>
      throw UnimplementedError('Stub');
  @override
  Stream<TaskData> listenAsAgent() => const Stream.empty();
}

class _StubWebUiService implements UiService {
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
  Future<bool> isLocationPickerActive() async => false;
  @override
  Future<bool> isPttActive() async => false;
  @override
  Future<bool> isStatusBarEnabled() async => false;
  String? _activeLeftPanel;
  @override
  Future<void> openLeftPanel(String panelId) async => _activeLeftPanel = panelId;
  @override
  Future<void> closeLeftPanel() async => _activeLeftPanel = null;
  @override
  Future<String?> getActiveLeftPanel() async => _activeLeftPanel;
  @override
  Future<void> showBanner(String message) async {}
  @override
  Future<void> hideBanner() async {}
  @override
  Future<void> setExtensionDisplayMode(String extensionId, String mode) async {}
  @override
  Future<void> resetUi() async {}
  @override
  Future<void> hideKeyboard() async {}
  bool _manualLocationEnabled = false;
  @override
  Future<void> setManualLocation(double lat, double lon) async => _manualLocationEnabled = true;
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
  Future<bool> enterText(Map<String, dynamic> selector, String text) async => true;
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

class _WebMessagingService implements MessagingService {
  final JSObject _bridge;
  final StreamController<IncomingMessage> _messageController =
      StreamController<IncomingMessage>.broadcast();
  final StreamController<List<Peer>> _peersController =
      StreamController<List<Peer>>.broadcast();

  _WebMessagingService(this._bridge) {
    // Register JS callback for incoming messages pushed from the host.
    web.window.setProperty(
      '__lattice_messaging_onMessage'.toJS,
      ((JSAny messageJs) {
        try {
          String jsonStr;
          if (messageJs.isA<JSString>()) {
            jsonStr = (messageJs as JSString).toDart;
          } else {
            final json = globalContext.getProperty('JSON'.toJS) as JSObject;
            final stringifyFn = json.getProperty('stringify'.toJS) as JSFunction;
            final result = stringifyFn.callAsFunction(json, messageJs);
            jsonStr = (result! as JSString).toDart;
          }
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          _messageController.add(IncomingMessage.fromJson(data));
        } catch (e) {
          // ignore malformed messages
        }
      }).toJS,
    );

    // Register JS callback for peer list changes pushed from the host.
    web.window.setProperty(
      '__lattice_messaging_onPeersChanged'.toJS,
      ((JSAny peersJs) {
        try {
          String jsonStr;
          if (peersJs.isA<JSString>()) {
            jsonStr = (peersJs as JSString).toDart;
          } else {
            final json = globalContext.getProperty('JSON'.toJS) as JSObject;
            final stringifyFn = json.getProperty('stringify'.toJS) as JSFunction;
            final result = stringifyFn.callAsFunction(json, peersJs);
            jsonStr = (result! as JSString).toDart;
          }
          final list = jsonDecode(jsonStr) as List;
          _peersController.add(
            list.map((p) => Peer.fromJson(p as Map<String, dynamic>)).toList(),
          );
        } catch (e) {
          // ignore malformed data
        }
      }).toJS,
    );
  }

  DeliveryReport _parseDeliveryReport(String? result) {
    if (result == null) return const DeliveryReport(results: []);
    final data = jsonDecode(result) as Map<String, dynamic>;
    final results = (data['results'] as List?)
            ?.map((r) => DeliveryResult.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    return DeliveryReport(results: results);
  }

  @override
  Future<List<Peer>> getPeers() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'getPeers',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List?;
    if (list == null) return [];
    return list.map((p) => Peer.fromJson(p as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Peer>> get onPeersChanged => _peersController.stream;

  @override
  Future<List<Peer>?> pickRecipients() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'pickRecipients',
    );
    if (result == null) return null;
    final list = jsonDecode(result) as List?;
    if (list == null) return null;
    return list.map((p) => Peer.fromJson(p as Map<String, dynamic>)).toList();
  }

  @override
  Future<DeliveryReport> send(String peerId, String payload) async {
    final arg = jsonEncode({'peerId': peerId, 'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'send', [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> sendToMultiple(
      List<String> peerIds, String payload) async {
    final arg = jsonEncode({'peerIds': peerIds, 'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'sendToMultiple', [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> sendToGroup(String groupId, String payload) async {
    final arg = jsonEncode({'groupId': groupId, 'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'sendToGroup', [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> broadcast(String payload) async {
    final arg = jsonEncode({'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'broadcast', [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Stream<IncomingMessage> get onMessageReceived => _messageController.stream;

  @override
  Future<int> getUnreadCount() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'getUnreadCount',
    );
    if (result == null) return 0;
    return jsonDecode(result) as int? ?? 0;
  }

  @override
  Future<void> markAsRead(String messageId) async {
    final arg = jsonEncode({'messageId': messageId});
    await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'markAsRead', [arg],
    );
  }

  @override
  Future<void> markAllAsRead() async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'markAllAsRead',
    );
  }

  @override
  Future<List<ContactGroup>> getGroups() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'messaging', 'getGroups',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List?;
    if (list == null) return [];
    return list
        .map((g) => ContactGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }
}

class _StubWebMessagingService implements MessagingService {
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
      DeliveryReport(results: []);
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

class _WebStorageService implements StorageService {
  final JSObject _bridge;
  _WebStorageService(this._bridge);

  @override
  Future<String?> read(String key) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'storage', 'read', [key],
    );
    if (result == null) return null;
    return jsonDecode(result) as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    // Pass key and value as two separate args — the JS bridge's
    // storage.write(key, value) takes two positional arguments.
    await WebExtensionContext._callNestedBridge(
      _bridge, 'storage', 'write', [key, value],
    );
  }

  @override
  Future<void> delete(String key) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'storage', 'delete', [key],
    );
  }
}

class _WebEntityService implements EntityService {
  final JSObject _bridge;
  _WebEntityService(this._bridge);

  @override
  Future<PublishEntityResult> publishEntity(PublishEntityRequest request) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'publishEntity', [jsonEncode(request.toJson())],
    );
    if (result == null) {
      throw StateError('publishEntity returned null');
    }
    final map = jsonDecode(result) as Map<String, dynamic>;
    return PublishEntityResult(
      entityId: map['entityId'] as String,
      displayName: map['displayName'] as String,
    );
  }

  @override
  Future<Entity?> getEntity(String entityId) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'getEntity', [entityId],
    );
    if (result == null) return null;
    return Entity.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<List<Entity>> getEntities() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'getEntities',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Entity>> searchEntities(String query) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'searchEntities', [query],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Entity>> getNearbyEntities(
      double lat, double lon, double radiusMeters) async {
    final arg = jsonEncode({
      'lat': lat,
      'lon': lon,
      'radiusMeters': radiusMeters,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'getNearbyEntities', [arg],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> upsertEntity(Entity entity) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'entities', 'upsertEntity', [jsonEncode(entity.toJson())],
    );
    if (result == null) {
      throw StateError('upsertEntity returned null');
    }
    final data = jsonDecode(result);
    if (data is Map && data['entityId'] != null) {
      return data['entityId'] as String;
    }
    if (data is String) return data;
    return entity.id;
  }

  @override
  Stream<EntityEvent> streamEntityComponents() {
    return const Stream.empty();
  }
}

class _WebTaskService implements TaskService {
  final JSObject _bridge;
  _WebTaskService(this._bridge);

  @override
  Future<TaskData> createTask(CreateTaskParams params) async {
    final arg = jsonEncode({
      'specificationTypeUrl': params.specificationTypeUrl,
      'specificationBytes': params.specificationBytes,
      'description': params.description,
      'assigneeEntityId': params.assigneeEntityId,
      'parentTaskId': params.parentTaskId,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'tasks', 'createTask', [arg],
    );
    if (result == null) {
      throw StateError('createTask returned null');
    }
    return TaskData.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<TaskData?> getTask(String taskId) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'tasks', 'getTask', [taskId],
    );
    if (result == null) return null;
    return TaskData.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<TaskData> updateStatus(String taskId, int newRawStatus,
      {String? errorMessage, int? errorCode}) async {
    final arg = jsonEncode({
      'taskId': taskId,
      'newRawStatus': newRawStatus,
      'errorMessage': errorMessage,
      'errorCode': errorCode,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'tasks', 'updateStatus', [arg],
    );
    if (result == null) {
      throw StateError('updateStatus returned null');
    }
    return TaskData.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<TaskData> cancelTask(String taskId, {String? reason}) async {
    final arg = jsonEncode({'taskId': taskId, 'reason': reason});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'tasks', 'cancelTask', [arg],
    );
    if (result == null) {
      throw StateError('cancelTask returned null');
    }
    return TaskData.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<List<TaskData>> queryTasks({
    String? assigneeEntityId,
    String? authorUserId,
    List<TaskStatusGroup>? statusGroups,
    String? specTypeUrl,
  }) async {
    final arg = jsonEncode({
      'assigneeEntityId': assigneeEntityId,
      'authorUserId': authorUserId,
      'statusGroups': statusGroups?.map((s) => s.name).toList(),
      'specTypeUrl': specTypeUrl,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'tasks', 'queryTasks', [arg],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list
        .map((e) => TaskData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Stream<TaskData> listenAsAgent() => const Stream.empty();
}

class _WebUiService implements UiService {
  final JSObject _bridge;
  _WebUiService(this._bridge);

  @override
  Future<void> navigateTo(String viewId) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'navigateTo', [viewId]);
  }

  @override
  Future<String> getActiveView() async {
    final result = await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'getActiveView');
    return result ?? 'map';
  }

  @override
  Future<void> openPanel(String panelId) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'openPanel', [panelId]);
  }

  @override
  Future<void> closePanel() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'closePanel');
  }

  @override
  Future<String?> getActivePanel() async {
    return await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'getActivePanel');
  }

  @override
  Future<void> openExtension(String extensionId) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'openExtension', [extensionId]);
  }

  @override
  Future<void> closeExtension(String extensionId) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'closeExtension', [extensionId]);
  }

  @override
  Future<String?> getActiveExtension() async {
    return await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'getActiveExtension');
  }

  @override
  Future<bool> isLocationPickerActive() async {
    final result = await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'isLocationPickerActive');
    return result == 'true';
  }

  @override
  Future<bool> isPttActive() async {
    final result = await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'isPttActive');
    return result == 'true';
  }

  @override
  Future<bool> isStatusBarEnabled() async {
    final result = await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'isStatusBarEnabled');
    return result == 'true';
  }

  @override
  Future<void> openLeftPanel(String panelId) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'openLeftPanel', [panelId]);
  }

  @override
  Future<void> closeLeftPanel() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'closeLeftPanel');
  }

  @override
  Future<String?> getActiveLeftPanel() async {
    return await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'getActiveLeftPanel');
  }

  @override
  Future<void> showBanner(String message) async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'showBanner', [message]);
  }

  @override
  Future<void> hideBanner() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'hideBanner');
  }

  @override
  Future<void> setExtensionDisplayMode(String extensionId, String mode) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'setExtensionDisplayMode',
      [jsonEncode({'extensionId': extensionId, 'mode': mode})],
    );
  }

  @override
  Future<void> resetUi() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'resetUi');
  }

  @override
  Future<void> hideKeyboard() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'hideKeyboard');
  }

  @override
  Future<void> setManualLocation(double lat, double lon) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'setManualLocation',
      [jsonEncode({'lat': lat, 'lon': lon})],
    );
  }

  @override
  Future<void> clearManualLocation() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'clearManualLocation');
  }

  @override
  Future<bool> isManualLocationEnabled() async {
    final result = await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'isManualLocationEnabled');
    return result == 'true';
  }

  @override
  Future<bool> tapWidget(Map<String, dynamic> selector) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'tapWidget', [jsonEncode(selector)],
    );
    return result == 'true';
  }

  @override
  Future<void> tapAt(double x, double y) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'tapAt', [jsonEncode({'x': x, 'y': y})],
    );
  }

  @override
  Future<void> longPressAt(double x, double y, {int holdMs = 600}) async {
    await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'longPressAt',
      [jsonEncode({'x': x, 'y': y, 'holdMs': holdMs})],
    );
  }

  @override
  Future<bool> enterText(Map<String, dynamic> selector, String text) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'enterText',
      [jsonEncode({'selector': selector, 'text': text})],
    );
    return result == 'true';
  }

  @override
  Future<List<String>> getVisibleLabels() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'ui', 'getVisibleLabels',
    );
    if (result == null) return [];
    try {
      final list = jsonDecode(result);
      if (list is List) return list.cast<String>();
    } catch (_) {}
    return [];
  }

  @override
  Future<Map<String, dynamic>?> waitForEvent(
    String type, {
    Map<String, dynamic>? match,
    int timeoutMs = 30000,
    int lookbackMs = 2500,
  }) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'waitForEvent',
      [
        jsonEncode({
          'type': type,
          'match': match,
          'timeoutMs': timeoutMs,
          'lookbackMs': lookbackMs,
        })
      ],
    );
    if (result == null) return null;
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}

class _WebAiService implements AiService {
  final JSObject _bridge;
  _WebAiService(this._bridge);
  late final AiChatCompletions _chat = _WebAiChatCompletions(_bridge);
  @override
  AiChatCompletions get chat => _chat;
  @override
  Future<void> clearHistory() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ai', 'clearHistory');
  }
}

class _WebAiChatCompletions implements AiChatCompletions {
  final JSObject _bridge;
  _WebAiChatCompletions(this._bridge);
  late final AiCompletions _completions = _WebAiCompletions(_bridge);
  @override
  AiCompletions get completions => _completions;
}

class _WebAiCompletions implements AiCompletions {
  final JSObject _bridge;
  _WebAiCompletions(this._bridge);

  @override
  Stream<ChatCompletionChunk> createStream(ChatCompletionRequest request) {
    final controller = StreamController<ChatCompletionChunk>();
    _startStream(controller, request);
    return controller.stream;
  }

  Future<void> _startStream(
    StreamController<ChatCompletionChunk> controller,
    ChatCompletionRequest request,
  ) async {
    try {
      // Generate requestId client-side and register callbacks FIRST to avoid
      // losing early chunks that arrive before the await returns.
      final requestId =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
              DateTime.now().microsecond.toRadixString(36);

      final onChunk = (JSAny? data) {
        if (controller.isClosed) return;
        try {
          final jsonStr = (data as JSString).toDart;
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          controller.add(ChatCompletionChunk.fromJson(json));
        } catch (e) {
          controller.addError(e);
        }
      }.toJS;

      final onDone = (() {
        if (!controller.isClosed) controller.close();
      }).toJS;

      final window = globalContext;
      window.setProperty('__lattice_ai_stream_$requestId'.toJS, onChunk);
      window.setProperty('__lattice_ai_stream_done_$requestId'.toJS, onDone);

      controller.onCancel = () {
        window.delete('__lattice_ai_stream_$requestId'.toJS);
        window.delete('__lattice_ai_stream_done_$requestId'.toJS);
        WebExtensionContext._callNestedBridge(_bridge, 'ai', 'cancel', [requestId]);
      };

      // NOW make the bridge call — callbacks are already registered.
      final payload = request.toJson();
      payload['stream'] = true;
      payload['requestId'] = requestId;
      final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ai', 'createStream', [jsonEncode(payload)],
      );

      if (result == null && !controller.isClosed) {
        controller.addError(StateError('ai.createStream returned null'));
        await controller.close();
      }
    } catch (e) {
      controller.addError(e);
      await controller.close();
    }
  }

  @override
  Future<ChatCompletion> create(ChatCompletionRequest request) async {
    final payload = request.toJson();
    payload['stream'] = false;
    final result = await WebExtensionContext._callNestedBridge(
      _bridge, 'ai', 'create', [jsonEncode(payload)],
    );
    if (result == null) throw StateError('ai.create returned null');
    final json = jsonDecode(result) as Map<String, dynamic>;
    return ChatCompletion.fromJson(json);
  }
}

class _StubWebAiService implements AiService {
  late final AiChatCompletions _chat = _StubWebAiChatCompletions();
  @override
  AiChatCompletions get chat => _chat;
  @override
  Future<void> clearHistory() async {}
}

class _StubWebAiChatCompletions implements AiChatCompletions {
  late final AiCompletions _completions = _StubWebAiCompletions();
  @override
  AiCompletions get completions => _completions;
}

class _StubWebAiCompletions implements AiCompletions {
  @override
  Stream<ChatCompletionChunk> createStream(ChatCompletionRequest request) async* {
    final id = 'stub-${DateTime.now().millisecondsSinceEpoch}';
    yield ChatCompletionChunk(id: id, choices: [
      ChatChunkChoice(index: 0, delta: const ChatCompletionDelta(role: 'assistant')),
    ]);
    yield ChatCompletionChunk(id: id, choices: [
      ChatChunkChoice(index: 0, delta: const ChatCompletionDelta(content: 'Simulated AI response.'), finishReason: 'stop'),
    ]);
  }

  @override
  Future<ChatCompletion> create(ChatCompletionRequest request) async {
    return ChatCompletion(id: 'stub-${DateTime.now().millisecondsSinceEpoch}', choices: [
      ChatChoice(index: 0, message: const ChatCompletionMessage(role: 'assistant', content: 'Simulated AI response.'), finishReason: 'stop'),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Web stubs for device/peripherals (not available in web extensions)
// ---------------------------------------------------------------------------

class _WebUsbSerialService implements UsbSerialService {
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
      '{"success":false,"message":"USB serial not available in web mode"}';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<String> listDevices() async => '[]';

  @override
  void dispose() {}
}

class _WebDeviceService implements DeviceService {
  final UsbSerialService _usbSerial = _WebUsbSerialService();

  @override
  UsbSerialService get usbSerial => _usbSerial;
}

class _WebRangeFinderService implements RangeFinderService {
  final _controller = StreamController<RangeFinderTarget>.broadcast();

  @override
  void publishTarget(RangeFinderTarget target) => _controller.add(target);

  @override
  Stream<RangeFinderTarget> get targetStream => _controller.stream;
}

class _WebPeripheralsService implements PeripheralsService {
  final RangeFinderService _rangeFinder = _WebRangeFinderService();

  @override
  RangeFinderService get rangeFinder => _rangeFinder;
}
