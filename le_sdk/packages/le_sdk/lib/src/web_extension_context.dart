import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ai_service.dart';
import 'object_service.dart';
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
  late final MeshItemStoreService _meshItemStore;
  late final ObjectService _objects;
  // USB serial and peripherals are not available in web extensions.
  final DeviceService _device = _WebDeviceService();
  final PeripheralsService _peripherals = _WebPeripheralsService();
  late final NetworkService _network;

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
    ctx._meshItemStore = _WebMeshItemStoreService(
      _WebMeshItemService(bridge),
      _WebMeshStreamService(bridge),
    );
    ctx._objects = _WebObjectService(bridge);
    ctx._network = _WebNetworkService(bridge);
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
        if (!completer.isCompleted &&
            bridge != null &&
            bridge.isA<JSObject>()) {
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
      _bridge,
      'map',
      'pickLocation',
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
      _bridge,
      'map',
      'addMarker',
      [payload],
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
      _bridge,
      'map',
      'removeMarker',
      [id],
    );
  }

  @override
  Future<List<MapMarker>> getMarkers() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'getMarkers',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List?;
    if (list == null) return [];
    return list
        .map((m) => MapMarker.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> clearMarkers() async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'clearMarkers',
    );
  }

  @override
  Future<void> addPolyline(String id, List<LatLng> points,
      {String? color,
      double? width,
      List<double>? dashPattern,
      double? opacity}) async {
    final payload = jsonEncode({
      'id': id,
      'points': points.map((p) => p.toJson()).toList(),
      if (color != null) 'color': color,
      if (width != null) 'width': width,
      if (dashPattern != null) 'dashPattern': dashPattern,
      if (opacity != null) 'opacity': opacity,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'addPolyline',
      [payload],
    );
  }

  @override
  Future<void> removePolyline(String id) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'removePolyline',
      [id],
    );
  }

  @override
  Future<void> clearPolylines() async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'clearPolylines',
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
      _bridge,
      'map',
      'flyTo',
      [payload],
    );
  }

  @override
  Future<ScreenPoint?> getPixelFromLocation(LatLng location) async {
    final payload = jsonEncode({
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'getPixelFromLocation',
      [payload],
    );
    if (result == null || result == 'null') return null;
    final data = jsonDecode(result.toString()) as Map<String, dynamic>;
    return ScreenPoint.fromJson(data);
  }

  @override
  Future<bool> simulateMarkerTap(String entityId) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'simulateMarkerTap',
      [
        jsonEncode({'entityId': entityId})
      ],
    );
    return result == 'true' || result == '{"success":true}';
  }

  @override
  Future<Uint8List?> captureMap({
    List<LatLng>? quad,
    List<String>? columnLabels,
    List<String>? rowLabels,
  }) async {
    // Not bridged for web extensions: the JS bridge is string-based, so image
    // bytes would need base64 and a dedicated host case. Native (in-process)
    // extensions get the real implementation via HostMapService; web plugins
    // fall back to null (their own rendering).
    return null;
  }

  @override
  Future<void> addPolygon(String id, List<LatLng> points,
      {String? strokeColor, String? fillColor}) async {
    final payload = jsonEncode({
      'id': id,
      'points': points.map((p) => p.toJson()).toList(),
      if (strokeColor != null) 'strokeColor': strokeColor,
      if (fillColor != null) 'fillColor': fillColor,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'addPolygon',
      [payload],
    );
  }

  @override
  Future<void> updatePolygon(String id, List<LatLng> points,
      {String? strokeColor, String? fillColor}) async {
    final payload = jsonEncode({
      'id': id,
      'points': points.map((p) => p.toJson()).toList(),
      if (strokeColor != null) 'strokeColor': strokeColor,
      if (fillColor != null) 'fillColor': fillColor,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'updatePolygon',
      [payload],
    );
  }

  @override
  Future<void> removePolygon(String id) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'removePolygon',
      [id],
    );
  }

  @override
  Future<void> addTacticalGraphic(String id, String sidc, List<LatLng> points,
      {Map<String, String>? modifiers}) async {
    final payload = jsonEncode({
      'id': id,
      'sidc': sidc,
      'points': points.map((p) => p.toJson()).toList(),
      if (modifiers != null) 'modifiers': modifiers,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'addTacticalGraphic',
      [payload],
    );
  }

  @override
  Future<void> updateTacticalGraphic(String id,
      {String? sidc,
      List<LatLng>? points,
      Map<String, String>? modifiers}) async {
    final payload = jsonEncode({
      'id': id,
      if (sidc != null) 'sidc': sidc,
      if (points != null) 'points': points.map((p) => p.toJson()).toList(),
      if (modifiers != null) 'modifiers': modifiers,
    });
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'updateTacticalGraphic',
      [payload],
    );
  }

  @override
  Future<void> removeTacticalGraphic(String id) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'removeTacticalGraphic',
      [id],
    );
  }

  @override
  Future<List<LatLng>?> drawPolygon({
    String? previewStrokeColor,
    String? previewFillColor,
    String? toolbarHint,
  }) async {
    final payload = jsonEncode({
      if (previewStrokeColor != null) 'previewStrokeColor': previewStrokeColor,
      if (previewFillColor != null) 'previewFillColor': previewFillColor,
      if (toolbarHint != null) 'toolbarHint': toolbarHint,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'drawPolygon',
      [payload],
    );
    if (result == null) return null;
    final data = jsonDecode(result);
    if (data == null) return null;
    final list = data as List?;
    if (list == null) return null;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return LatLng(
        (m['latitude'] as num).toDouble(),
        (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<LatLng>?> drawPolyline({
    String? previewColor,
    double? previewWidth,
    String? toolbarHint,
  }) async {
    final payload = jsonEncode({
      if (previewColor != null) 'previewColor': previewColor,
      if (previewWidth != null) 'previewWidth': previewWidth,
      if (toolbarHint != null) 'toolbarHint': toolbarHint,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'map',
      'drawPolyline',
      [payload],
    );
    if (result == null) return null;
    final data = jsonDecode(result);
    if (data == null) return null;
    final list = data as List?;
    if (list == null) return null;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return LatLng(
        (m['latitude'] as num).toDouble(),
        (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }
}

class _WebLocationService implements LocationService {
  final JSObject _bridge;
  _WebLocationService(this._bridge);

  @override
  Future<LatLng?> getCurrentLocation() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'location',
      'getCurrentLocation',
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
      _bridge,
      'speech',
      'dictate',
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
  late final MeshItemStoreService _meshItemStore = _StubMeshItemStoreService(
    _StubMeshItemService(),
    _StubMeshStreamService(),
  );
  late final ObjectService _objects = _StubWebObjectService();
  final DeviceService _device = _WebDeviceService();
  final PeripheralsService _peripherals = _WebPeripheralsService();
  late final NetworkService _network = _StubWebNetworkService();

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
  Future<LatLng?> pickLocation() async =>
      const LatLng(33.69377185495327, -117.91658086952512);
  @override
  Future<String> addMarker(LatLng location,
          {String? label,
          String? color,
          MarkerIcon? icon,
          MarkerDisposition? disposition}) async =>
      'stub_${_nextId++}';
  @override
  Future<void> removeMarker(String id) async {}
  @override
  Future<List<MapMarker>> getMarkers() async => [];
  @override
  Future<void> clearMarkers() async {}
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
      const PublishEntityResult(entityId: 'stub', displayName: 'Stub');
  @override
  Future<String> upsertEntity(Entity entity) async => entity.id;
  @override
  Future<void> deleteEntity(String entityId) async {}
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
  Future<void> resetUi() async {}
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
            final stringifyFn =
                json.getProperty('stringify'.toJS) as JSFunction;
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
            final stringifyFn =
                json.getProperty('stringify'.toJS) as JSFunction;
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
      _bridge,
      'messaging',
      'getPeers',
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
      _bridge,
      'messaging',
      'pickRecipients',
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
      _bridge,
      'messaging',
      'send',
      [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> sendToMultiple(
      List<String> peerIds, String payload) async {
    final arg = jsonEncode({'peerIds': peerIds, 'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'sendToMultiple',
      [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> sendToGroup(String groupId, String payload) async {
    final arg = jsonEncode({'groupId': groupId, 'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'sendToGroup',
      [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Future<DeliveryReport> broadcast(String payload) async {
    final arg = jsonEncode({'payload': payload});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'broadcast',
      [arg],
    );
    return _parseDeliveryReport(result);
  }

  @override
  Stream<IncomingMessage> get onMessageReceived => _messageController.stream;

  @override
  Future<int> getUnreadCount() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'getUnreadCount',
    );
    if (result == null) return 0;
    return jsonDecode(result) as int? ?? 0;
  }

  @override
  Future<void> markAsRead(String messageId) async {
    final arg = jsonEncode({'messageId': messageId});
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'markAsRead',
      [arg],
    );
  }

  @override
  Future<void> markAllAsRead() async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'markAllAsRead',
    );
  }

  @override
  Future<List<ContactGroup>> getGroups() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'messaging',
      'getGroups',
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

class _WebStorageService implements StorageService {
  final JSObject _bridge;
  _WebStorageService(this._bridge);

  @override
  Future<String?> read(String key) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'storage',
      'read',
      [key],
    );
    if (result == null) return null;
    // `_callBridge` already returns the stored string: the injected bridge
    // `call()` JSON.parse()s the channel result, and `_callBridge` returns a
    // JSString verbatim. Decoding again here double-decodes — in release web
    // (dart2js sound casts) `jsonDecode(result) as String?` throws
    // `TypeError: ... is not a subtype of type 'String?'` whenever the stored
    // value is itself JSON (e.g. a serialized List/Map), silently breaking
    // read() for any plugin that persists structured data.
    return result;
  }

  @override
  Future<void> write(String key, String value) async {
    // Pass key and value as two separate args — the JS bridge's
    // storage.write(key, value) takes two positional arguments.
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'storage',
      'write',
      [key, value],
    );
  }

  @override
  Future<void> delete(String key) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'storage',
      'delete',
      [key],
    );
  }
}

class _WebEntityService implements EntityService {
  final JSObject _bridge;
  _WebEntityService(this._bridge);

  @override
  Future<PublishEntityResult> publishEntity(
      PublishEntityRequest request) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'entities',
      'publishEntity',
      [jsonEncode(request.toJson())],
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
      _bridge,
      'entities',
      'getEntity',
      [entityId],
    );
    if (result == null) return null;
    return Entity.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<List<Entity>> getEntities() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'entities',
      'getEntities',
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => Entity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Entity>> searchEntities(String query) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'entities',
      'searchEntities',
      [query],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => Entity.fromJson(e as Map<String, dynamic>)).toList();
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
      _bridge,
      'entities',
      'getNearbyEntities',
      [arg],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => Entity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> upsertEntity(Entity entity) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'entities',
      'upsertEntity',
      [jsonEncode(entity.toJson())],
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
  Future<void> deleteEntity(String entityId) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'entities',
      'deleteEntity',
      [entityId],
    );
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
      'initialEntities': params.initialEntities.map((e) => e.toJson()).toList(),
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'tasks',
      'createTask',
      [arg],
    );
    if (result == null) {
      throw StateError('createTask returned null');
    }
    return TaskData.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<TaskData?> getTask(String taskId) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'tasks',
      'getTask',
      [taskId],
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
      _bridge,
      'tasks',
      'updateStatus',
      [arg],
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
      _bridge,
      'tasks',
      'cancelTask',
      [arg],
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
      _bridge,
      'tasks',
      'queryTasks',
      [arg],
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
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'navigateTo', [viewId]);
  }

  @override
  Future<String> getActiveView() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'getActiveView');
    return result ?? 'map';
  }

  @override
  Future<void> openPanel(String panelId) async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'openPanel', [panelId]);
  }

  @override
  Future<void> closePanel() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'closePanel');
  }

  @override
  Future<String?> getActivePanel() async {
    return await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'getActivePanel');
  }

  @override
  Future<void> openExtension(String extensionId) async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'openExtension', [extensionId]);
  }

  @override
  Future<void> closeExtension(String extensionId) async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'closeExtension', [extensionId]);
  }

  @override
  Future<String?> getActiveExtension() async {
    return await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'getActiveExtension');
  }

  @override
  Future<Map<String, dynamic>?> getLaunchArgs() async {
    final raw = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'getLaunchArgs');
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  Future<String?> debugReadCommand() async {
    final raw = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'debugReadCommand');
    if (raw == null) return null;
    // Bridge returns the command JSON re-encoded as a JSON string; unwrap it.
    final decoded = jsonDecode(raw);
    return decoded is String ? decoded : null;
  }

  @override
  Future<bool> isLocationPickerActive() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'isLocationPickerActive');
    return result == 'true';
  }

  @override
  Future<bool> isPttActive() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'isPttActive');
    return result == 'true';
  }

  @override
  Future<bool> isStatusBarEnabled() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'isStatusBarEnabled');
    return result == 'true';
  }

  // Deprecated no-ops, intentionally NOT forwarded across the bridge: the left
  // sidebar was removed, so the host has nothing to call.
  @override
  Future<void> openLeftPanel(String panelId) async {}
  @override
  Future<void> closeLeftPanel() async {}
  @override
  Future<String?> getActiveLeftPanel() async => null;

  @override
  Future<void> showBanner(String message) async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'showBanner', [message]);
  }

  @override
  Future<void> hideBanner() async {
    await WebExtensionContext._callNestedBridge(_bridge, 'ui', 'hideBanner');
  }

  @override
  Future<void> setPanelSize(PanelSize size) async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'setPanelSize', [size.name]);
  }

  @override
  Future<PanelSize> getPanelSize() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'getPanelSize');
    if (result == null) return PanelSize.small;
    try {
      return PanelSize.values.byName(result.replaceAll('"', ''));
    } catch (_) {
      return PanelSize.small;
    }
  }

  @override
  Future<void> showToast(
    String message, {
    String type = 'info',
    String priority = 'routine',
  }) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'showToast',
      [
        jsonEncode({'message': message, 'type': type, 'priority': priority})
      ],
    );
  }

  @override
  Future<void> setExtensionDisplayMode(String extensionId, String mode) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'setExtensionDisplayMode',
      [
        jsonEncode({'extensionId': extensionId, 'mode': mode})
      ],
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
      _bridge,
      'ui',
      'setManualLocation',
      [
        jsonEncode({'lat': lat, 'lon': lon})
      ],
    );
  }

  @override
  Future<void> clearManualLocation() async {
    await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'clearManualLocation');
  }

  @override
  Future<bool> isManualLocationEnabled() async {
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'ui', 'isManualLocationEnabled');
    return result == 'true';
  }

  @override
  Future<bool> tapWidget(Map<String, dynamic> selector) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'tapWidget',
      [jsonEncode(selector)],
    );
    return result == 'true';
  }

  @override
  Future<void> tapAt(double x, double y) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'tapAt',
      [
        jsonEncode({'x': x, 'y': y})
      ],
    );
  }

  @override
  Future<void> longPressAt(double x, double y, {int holdMs = 600}) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'longPressAt',
      [
        jsonEncode({'x': x, 'y': y, 'holdMs': holdMs})
      ],
    );
  }

  @override
  Future<bool> enterText(Map<String, dynamic> selector, String text) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'enterText',
      [
        jsonEncode({'selector': selector, 'text': text})
      ],
    );
    return result == 'true';
  }

  @override
  Future<List<String>> getVisibleLabels() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'ui',
      'getVisibleLabels',
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
        WebExtensionContext._callNestedBridge(
            _bridge, 'ai', 'cancel', [requestId]);
      };

      // NOW make the bridge call — callbacks are already registered.
      final payload = request.toJson();
      payload['stream'] = true;
      payload['requestId'] = requestId;
      final result = await WebExtensionContext._callNestedBridge(
        _bridge,
        'ai',
        'createStream',
        [jsonEncode(payload)],
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
      _bridge,
      'ai',
      'create',
      [jsonEncode(payload)],
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
  Stream<ChatCompletionChunk> createStream(
      ChatCompletionRequest request) async* {
    final id = 'stub-${DateTime.now().millisecondsSinceEpoch}';
    yield ChatCompletionChunk(id: id, choices: [
      const ChatChunkChoice(
          index: 0, delta: ChatCompletionDelta(role: 'assistant')),
    ]);
    yield ChatCompletionChunk(id: id, choices: [
      const ChatChunkChoice(
          index: 0,
          delta: ChatCompletionDelta(content: 'Simulated AI response.'),
          finishReason: 'stop'),
    ]);
  }

  @override
  Future<ChatCompletion> create(ChatCompletionRequest request) async {
    return ChatCompletion(
        id: 'stub-${DateTime.now().millisecondsSinceEpoch}',
        choices: [
          const ChatChoice(
              index: 0,
              message: ChatCompletionMessage(
                  role: 'assistant', content: 'Simulated AI response.'),
              finishReason: 'stop'),
        ]);
  }
}

// ---------------------------------------------------------------------------
// Mesh item store — web client implementations
// ---------------------------------------------------------------------------

class _WebMeshItemStoreService implements MeshItemStoreService {
  _WebMeshItemStoreService(this.items, this.streams);

  @override
  final MeshItemService items;

  @override
  final MeshStreamService streams;
}

class _StubMeshItemStoreService implements MeshItemStoreService {
  _StubMeshItemStoreService(this.items, this.streams);

  @override
  final MeshItemService items;

  @override
  final MeshStreamService streams;
}

class _WebMeshItemService implements MeshItemService {
  final JSObject _bridge;
  _WebMeshItemService(this._bridge);

  MeshDataType _parseDataType(Map<String, dynamic> j) {
    return MeshDataType(
      path: MeshDataTypePath.fromJson(j['path'] as Map<String, dynamic>),
      schema: base64Decode(j['schema'] as String),
      isDeprecated: j['isDeprecated'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  MeshItem _parseItem(Map<String, dynamic> j) {
    return MeshItem(
      path: MeshItemPath.fromJson(j['path'] as Map<String, dynamic>),
      data: (j['data'] as Map<String, dynamic>).cast<String, Object?>(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      expiryTime: j['expiryTime'] != null
          ? DateTime.parse(j['expiryTime'] as String)
          : null,
    );
  }

  MeshBatchResult<MeshItem> _parseBatchItems(Map<String, dynamic> j) {
    final results = (j['results'] as List<dynamic>).map((r) {
      final m = r as Map<String, dynamic>;
      return MeshBatchEntry<MeshItem>(
        index: m['index'] as int,
        success: m['success'] as bool,
        value: m['value'] != null
            ? _parseItem(m['value'] as Map<String, dynamic>)
            : null,
        error: m['error'] as String?,
      );
    }).toList();
    return MeshBatchResult<MeshItem>(
      results: results,
      total: j['total'] as int,
      succeeded: j['succeeded'] as int,
      failed: j['failed'] as int,
    );
  }

  @override
  Future<List<MeshDataType>> listDataTypes() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'listDataTypes',
      [jsonEncode({})],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => _parseDataType(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<MeshDataType?> getDataType(MeshDataTypePath path) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'getDataType',
      [jsonEncode(path.toJson())],
    );
    if (result == null || result == 'null') return null;
    return _parseDataType(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<MeshItem> createItem(
    MeshDataTypePath type,
    Map<String, Object?> data, {
    Duration? ttl,
  }) async {
    final payload = jsonEncode({
      'type': type.toJson(),
      'data': data,
      if (ttl != null) 'ttlSec': ttl.inSeconds,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'createItem',
      [payload],
    );
    if (result == null) throw StateError('meshItems.createItem returned null');
    return _parseItem(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<MeshBatchResult<MeshItem>> createItems(
    MeshDataTypePath type,
    List<Map<String, Object?>> data, {
    Duration? ttl,
  }) async {
    final payload = jsonEncode({
      'type': type.toJson(),
      'data': data,
      if (ttl != null) 'ttlSec': ttl.inSeconds,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'createItems',
      [payload],
    );
    if (result == null) throw StateError('meshItems.createItems returned null');
    return _parseBatchItems(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<MeshItem?> getItem(MeshItemPath path) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'getItem',
      [jsonEncode(path.toJson())],
    );
    if (result == null || result == 'null') return null;
    return _parseItem(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<List<MeshItem>> listItems(
    MeshDataTypePath type, {
    Map<String, Object?>? filter,
  }) async {
    final payload = jsonEncode({
      'type': type.toJson(),
      if (filter != null) 'filter': filter,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'listItems',
      [payload],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => _parseItem(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<MeshItem> updateItem(
    MeshItemPath path,
    Map<String, Object?> data, {
    Duration? ttl,
  }) async {
    final payload = jsonEncode({
      'path': path.toJson(),
      'data': data,
      if (ttl != null) 'ttlSec': ttl.inSeconds,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'updateItem',
      [payload],
    );
    if (result == null) throw StateError('meshItems.updateItem returned null');
    return _parseItem(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteItem(MeshItemPath path) async {
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshItems',
      'deleteItem',
      [jsonEncode(path.toJson())],
    );
  }
}

class _WebMeshStreamService implements MeshStreamService {
  final JSObject _bridge;
  _WebMeshStreamService(this._bridge);

  MeshDataType _parseDataType(Map<String, dynamic> j) {
    return MeshDataType(
      path: MeshDataTypePath.fromJson(j['path'] as Map<String, dynamic>),
      schema: base64Decode(j['schema'] as String),
      isDeprecated: j['isDeprecated'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  @override
  Future<List<MeshDataType>> listStreamDataTypes() async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshStreams',
      'listStreamDataTypes',
      [jsonEncode({})],
    );
    if (result == null) return [];
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((e) => _parseDataType(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<MeshDataType?> getStreamDataType(MeshDataTypePath path) async {
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshStreams',
      'getStreamDataType',
      [jsonEncode(path.toJson())],
    );
    if (result == null || result == 'null') return null;
    return _parseDataType(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<MeshBatchResult<DateTime>> publish(
    MeshDataTypePath type,
    List<Map<String, Object?>> messages,
  ) async {
    final payload = jsonEncode({'type': type.toJson(), 'messages': messages});
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'meshStreams',
      'publish',
      [payload],
    );
    if (result == null) throw StateError('meshStreams.publish returned null');
    final j = jsonDecode(result) as Map<String, dynamic>;
    final results = (j['results'] as List<dynamic>).map((r) {
      final m = r as Map<String, dynamic>;
      return MeshBatchEntry<DateTime>(
        index: m['index'] as int,
        success: m['success'] as bool,
        value: m['value'] != null ? DateTime.parse(m['value'] as String) : null,
        error: m['error'] as String?,
      );
    }).toList();
    return MeshBatchResult<DateTime>(
      results: results,
      total: j['total'] as int,
      succeeded: j['succeeded'] as int,
      failed: j['failed'] as int,
    );
  }

  @override
  Stream<MeshStreamMessage> subscribe(MeshDataTypePath type) {
    final controller = StreamController<MeshStreamMessage>();
    _startSubscription(controller, type);
    return controller.stream;
  }

  Future<void> _startSubscription(
    StreamController<MeshStreamMessage> controller,
    MeshDataTypePath type,
  ) async {
    try {
      // Generate subscriptionId client-side and register callbacks FIRST to
      // avoid losing early messages that arrive before the await returns.
      final subscriptionId =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
              DateTime.now().microsecond.toRadixString(36);

      final window = globalContext;

      final onMessage = (JSAny? data) {
        if (controller.isClosed) return;
        try {
          String jsonStr;
          if (data != null && data.isA<JSString>()) {
            jsonStr = (data as JSString).toDart;
          } else {
            final json = globalContext.getProperty('JSON'.toJS) as JSObject;
            final stringify = json.getProperty('stringify'.toJS) as JSFunction;
            jsonStr =
                ((stringify.callAsFunction(json, data))! as JSString).toDart;
          }
          // The host base64-encodes the message envelope; decode it.
          final decoded = utf8.decode(base64Decode(jsonStr));
          final msg = MeshStreamMessage.fromJson(
            jsonDecode(decoded) as Map<String, dynamic>,
          );
          controller.add(msg);
        } catch (e) {
          controller.addError(e);
        }
      }.toJS;

      final onDone = (() {
        if (!controller.isClosed) controller.close();
      }).toJS;

      window.setProperty(
          '__lattice_meshstream_msg_$subscriptionId'.toJS, onMessage);
      window.setProperty(
          '__lattice_meshstream_done_$subscriptionId'.toJS, onDone);

      controller.onCancel = () {
        window.delete('__lattice_meshstream_msg_$subscriptionId'.toJS);
        window.delete('__lattice_meshstream_done_$subscriptionId'.toJS);
        WebExtensionContext._callNestedBridge(
          _bridge,
          'meshStreams',
          'cancelSubscribe',
          [
            jsonEncode({'subscriptionId': subscriptionId})
          ],
        );
      };

      // NOW make the bridge call — callbacks are already registered.
      final result = await WebExtensionContext._callNestedBridge(
        _bridge,
        'meshStreams',
        'subscribe',
        [
          jsonEncode({'subscriptionId': subscriptionId, 'type': type.toJson()})
        ],
      );

      if (result != null) {
        final response = jsonDecode(result) as Map<String, dynamic>;
        if (response['error'] != null) {
          // SSE handshake failed — tear down and reject.
          window.delete('__lattice_meshstream_msg_$subscriptionId'.toJS);
          window.delete('__lattice_meshstream_done_$subscriptionId'.toJS);
          controller.addError(
            StateError('meshStreams.subscribe failed: ${response['error']}'),
          );
          await controller.close();
        }
        // On success the host attaches the push callbacks and returns
        // {subscriptionId} — nothing more to do here.
      } else if (!controller.isClosed) {
        window.delete('__lattice_meshstream_msg_$subscriptionId'.toJS);
        window.delete('__lattice_meshstream_done_$subscriptionId'.toJS);
        controller.addError(StateError('meshStreams.subscribe returned null'));
        await controller.close();
      }
    } catch (e) {
      controller.addError(e);
      await controller.close();
    }
  }
}

// ---------------------------------------------------------------------------
// Stub implementations (shared by StubExtensionContext in both
// web_extension_context and stub_extension_context)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// NetworkService — web bridge client
// ---------------------------------------------------------------------------

/// Helper to generate a subscription ID matching the scheme used by
/// _WebAiCompletions (millisecondsSinceEpoch + microsecond in base-36).
String _newSubscriptionId() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    DateTime.now().microsecond.toRadixString(36);

/// Helper to convert a raw JS value to a Dart JSON string (same pattern as
/// _callBridge for non-string results).
String _jsAnyToJsonString(JSAny data) {
  if (data.isA<JSString>()) return (data as JSString).toDart;
  final json = globalContext.getProperty('JSON'.toJS) as JSObject;
  final stringify = json.getProperty('stringify'.toJS) as JSFunction;
  final result = stringify.callAsFunction(json, data);
  return (result! as JSString).toDart;
}

/// Live UDP subscription backed by a host-managed socket.
class _WebUdpSubscription implements UdpSubscription {
  final JSObject _bridge;
  final String _subscriptionId;
  final StreamController<UdpDatagram> _controller =
      StreamController<UdpDatagram>.broadcast();
  bool _closed = false;

  _WebUdpSubscription(this._bridge, this._subscriptionId);

  // BRIDGE CONTRACT — dgram push:
  //   window.__lattice_network_dgram_<subscriptionId>(base64JsonString)
  //   The argument is a base64-encoded UTF-8 JSON string of UdpDatagram.toJson().
  //   Decoding: base64Decode → utf8.decode → jsonDecode → UdpDatagram.fromJson
  void _onDatagram(JSAny? data) {
    if (_controller.isClosed) return;
    try {
      final raw = data == null ? '' : _jsAnyToJsonString(data);
      // The host pushes base64(JSON(UdpDatagram)) — decode accordingly.
      final jsonStr = utf8.decode(base64Decode(raw));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      _controller.add(UdpDatagram.fromJson(map));
    } catch (e) {
      // ignore malformed datagrams
    }
  }

  // BRIDGE CONTRACT — done push:
  //   window.__lattice_network_done_<subscriptionId>()
  //   Called when the host closes the socket (e.g. app shutdown).
  void _onDone() {
    if (!_controller.isClosed) _controller.close();
  }

  @override
  Stream<UdpDatagram> get datagrams => _controller.stream;

  // BRIDGE CONTRACT — send from bound socket:
  //   bridge.network.send(jsonPayload)
  //   payload: { subscriptionId: string, bytes: base64string, destinationIp?: string, port?: number }
  //   returns: JSON { success: bool, error?: string }
  @override
  Future<SendResult> send(Uint8List bytes,
      {String? destinationIp, int? port}) async {
    final payload = jsonEncode({
      'subscriptionId': _subscriptionId,
      'bytes': base64Encode(bytes),
      if (destinationIp != null) 'destinationIp': destinationIp,
      if (port != null) 'port': port,
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'network',
      'send',
      [payload],
    );
    if (result == null) {
      return const SendResult(success: false, error: 'null response');
    }
    return SendResult.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  // BRIDGE CONTRACT — unsubscribe:
  //   bridge.network.unsubscribe(jsonPayload)
  //   payload: { subscriptionId: string }
  //   returns: (ignored)
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Tear down window callbacks.
    final window = globalContext;
    window.delete('__lattice_network_dgram_$_subscriptionId'.toJS);
    window.delete('__lattice_network_done_$_subscriptionId'.toJS);
    if (!_controller.isClosed) await _controller.close();
    await WebExtensionContext._callNestedBridge(
      _bridge,
      'network',
      'unsubscribe',
      [
        jsonEncode({'subscriptionId': _subscriptionId})
      ],
    );
  }
}

class _WebNetworkService implements NetworkService {
  final JSObject _bridge;
  _WebNetworkService(this._bridge);

  // BRIDGE CONTRACT SUMMARY
  // ========================
  // All methods are on bridge.network (nested bridge group "network").
  //
  // network.subscribeMulticast(payload)
  //   payload: { subscriptionId: string, group: string, port: number }
  //   returns: JSON { error?: string }  — presence of "error" key signals failure
  //
  // network.subscribeUnicast(payload)
  //   payload: { subscriptionId: string, port: number }
  //   returns: JSON { error?: string }  — presence of "error" key signals failure
  //
  // network.send(payload)
  //   payload: { subscriptionId: string, bytes: base64string, destinationIp?: string, port?: number }
  //   returns: JSON { success: bool, error?: string }
  //
  // network.unsubscribe(payload)
  //   payload: { subscriptionId: string }
  //   returns: (ignored)
  //
  // network.sendMulticast(payload)
  //   payload: { group: string, port: number, bytes: base64string }
  //   returns: JSON { success: bool, error?: string }
  //
  // network.sendUnicast(payload)
  //   payload: { destinationIp: string, port: number, bytes: base64string }
  //   returns: JSON { success: bool, error?: string }
  //
  // Datagram push (host → Dart, per subscription):
  //   window.__lattice_network_dgram_<subscriptionId>(base64EncodedUtf8JsonString)
  //   where the JSON string decodes to UdpDatagram.toJson() shape.
  //
  // Socket-close push (host → Dart, per subscription):
  //   window.__lattice_network_done_<subscriptionId>()

  Future<UdpSubscription> _subscribe(Map<String, dynamic> payload) async {
    final subscriptionId = payload['subscriptionId'] as String;
    final sub = _WebUdpSubscription(_bridge, subscriptionId);

    // Register callbacks BEFORE making the bridge call — prevents losing early
    // datagrams (same critical ordering as AI streaming in _WebAiCompletions).
    final window = globalContext;
    window.setProperty(
      '__lattice_network_dgram_$subscriptionId'.toJS,
      ((JSAny? data) => sub._onDatagram(data)).toJS,
    );
    window.setProperty(
      '__lattice_network_done_$subscriptionId'.toJS,
      (() => sub._onDone()).toJS,
    );

    final method = payload.containsKey('group')
        ? 'subscribeMulticast'
        : 'subscribeUnicast';
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'network',
      method,
      [jsonEncode(payload)],
    );

    // If the bridge signals an error, tear down and throw.
    if (result != null) {
      final decoded = jsonDecode(result);
      if (decoded is Map &&
          decoded.containsKey('error') &&
          decoded['error'] != null) {
        window.delete('__lattice_network_dgram_$subscriptionId'.toJS);
        window.delete('__lattice_network_done_$subscriptionId'.toJS);
        throw StateError('$method failed: ${decoded['error']}');
      }
    }

    return sub;
  }

  @override
  Future<UdpSubscription> subscribeMulticast(String group, int port) {
    final subscriptionId = _newSubscriptionId();
    return _subscribe(
        {'subscriptionId': subscriptionId, 'group': group, 'port': port});
  }

  @override
  Future<UdpSubscription> subscribeUnicast(int port) {
    final subscriptionId = _newSubscriptionId();
    return _subscribe({'subscriptionId': subscriptionId, 'port': port});
  }

  @override
  Future<SendResult> sendMulticast(
      String group, int port, Uint8List bytes) async {
    final payload = jsonEncode({
      'group': group,
      'port': port,
      'bytes': base64Encode(bytes),
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'network',
      'sendMulticast',
      [payload],
    );
    if (result == null) {
      return const SendResult(success: false, error: 'null response');
    }
    return SendResult.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }

  @override
  Future<SendResult> sendUnicast(
      String destinationIp, int port, Uint8List bytes) async {
    final payload = jsonEncode({
      'destinationIp': destinationIp,
      'port': port,
      'bytes': base64Encode(bytes),
    });
    final result = await WebExtensionContext._callNestedBridge(
      _bridge,
      'network',
      'sendUnicast',
      [payload],
    );
    if (result == null) {
      return const SendResult(success: false, error: 'null response');
    }
    return SendResult.fromJson(jsonDecode(result) as Map<String, dynamic>);
  }
}

// ---------------------------------------------------------------------------
// Stub network service for StubExtensionContext (web standalone preview)
// ---------------------------------------------------------------------------

class _StubWebUdpSubscription implements UdpSubscription {
  @override
  Stream<UdpDatagram> get datagrams => const Stream.empty();

  @override
  Future<SendResult> send(Uint8List bytes,
          {String? destinationIp, int? port}) async =>
      const SendResult(success: false, error: 'stub');

  @override
  Future<void> close() async {}
}

class _StubWebNetworkService implements NetworkService {
  @override
  Future<UdpSubscription> subscribeMulticast(String group, int port) async =>
      _StubWebUdpSubscription();

  @override
  Future<UdpSubscription> subscribeUnicast(int port) async =>
      _StubWebUdpSubscription();

  @override
  Future<SendResult> sendMulticast(
          String group, int port, Uint8List bytes) async =>
      const SendResult(success: false, error: 'stub');

  @override
  Future<SendResult> sendUnicast(
          String destinationIp, int port, Uint8List bytes) async =>
      const SendResult(success: false, error: 'stub');
}

// ---------------------------------------------------------------------------
// Objects — Web implementation (bridge) + Stub (standalone preview)
// ---------------------------------------------------------------------------

class _WebObjectService implements ObjectService {
  _WebObjectService(this._bridge);
  final JSObject _bridge;

  @override
  Future<ObjectUploadResult> upload(String path, Uint8List bytes,
      {String? contentType, Duration? ttl}) async {
    final payload = jsonEncode({
      'path': path,
      'bytes': base64Encode(bytes),
      if (contentType != null) 'contentType': contentType,
      if (ttl != null) 'ttl': ttl.inSeconds,
    });
    final result = await WebExtensionContext._callNestedBridge(
            _bridge, 'objects', 'upload', [payload]) ??
        '{}';
    final json = jsonDecode(result) as Map<String, dynamic>;
    return ObjectUploadResult(
      path: json['path'] as String? ?? path,
      checksum: json['checksum'] as String?,
    );
  }

  @override
  Future<Uint8List?> download(String path) async {
    final payload = jsonEncode({'path': path});
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'objects', 'download', [payload]);
    if (result == null || result == 'null') return null;
    final json = jsonDecode(result) as Map<String, dynamic>;
    final b64 = json['bytes'] as String?;
    return b64 != null ? base64Decode(b64) : null;
  }

  @override
  Future<List<ObjectMetadata>> list({String? prefix}) async {
    final payload = jsonEncode({
      if (prefix != null) 'prefix': prefix,
    });
    final result = await WebExtensionContext._callNestedBridge(
            _bridge, 'objects', 'list', [payload]) ??
        '[]';
    final decoded = jsonDecode(result);
    final list = decoded is List ? decoded : (decoded as Map)['items'] as List?;
    return (list ?? [])
        .cast<Map<String, dynamic>>()
        .map((m) => ObjectMetadata(
              path: m['path'] as String? ?? '',
              sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
              lastUpdatedAt:
                  DateTime.tryParse(m['lastUpdatedAt'] as String? ?? '') ??
                      DateTime(0),
              expiryTime: DateTime.tryParse(m['expiryTime'] as String? ?? ''),
              checksum: m['checksum'] as String?,
            ))
        .toList();
  }

  @override
  Future<void> delete(String path) async {
    final payload = jsonEncode({'path': path});
    await WebExtensionContext._callNestedBridge(
        _bridge, 'objects', 'delete', [payload]);
  }

  @override
  Future<ObjectMetadata?> getMetadata(String path) async {
    final payload = jsonEncode({'path': path});
    final result = await WebExtensionContext._callNestedBridge(
        _bridge, 'objects', 'getMetadata', [payload]);
    if (result == null || result == 'null') return null;
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json.isEmpty) return null;
    return ObjectMetadata(
      path: json['path'] as String? ?? path,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      lastUpdatedAt:
          DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '') ??
              DateTime(0),
      expiryTime: DateTime.tryParse(json['expiryTime'] as String? ?? ''),
      checksum: json['checksum'] as String?,
    );
  }
}

class _StubWebObjectService implements ObjectService {
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
