import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/entities/publish_result.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';
import 'package:recovery_ops/domain/usecases/navigation/poll_route_geometry.dart';
import 'package:recovery_ops/domain/usecases/navigation/sync_navigator_states.dart';
import 'package:recovery_ops/domain/usecases/navigation/view_report_on_map.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_deletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:recovery_ops/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:recovery_ops/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_snack_bar.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';

class FakeMessagingService implements sdk.MessagingService {
  final StreamController<sdk.IncomingMessage> _controller =
      StreamController<sdk.IncomingMessage>.broadcast();

  @override
  Stream<sdk.IncomingMessage> get onMessageReceived => _controller.stream;

  void emitMessage(sdk.IncomingMessage msg) => _controller.add(msg);

  void dispose() => _controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMapService implements sdk.MapService {
  final List<String> addedMarkerLabels = [];
  final List<String> removedMarkerIds = [];
  final List<String> addedPolylineIds = [];
  final List<String> removedPolylineIds = [];
  final List<sdk.LatLng> flyToLocations = [];
  int _markerCounter = 0;

  @override
  Future<String> addMarker(sdk.LatLng location,
      {String? label,
      String? color,
      sdk.MarkerIcon? icon,
      sdk.MarkerDisposition? disposition}) async {
    addedMarkerLabels.add(label ?? '');
    return 'marker-${_markerCounter++}';
  }

  @override
  Future<void> removeMarker(String id) async {
    removedMarkerIds.add(id);
  }

  @override
  Future<void> addPolyline(String id, List<sdk.LatLng> points,
      {String? color}) async {
    addedPolylineIds.add(id);
  }

  @override
  Future<void> removePolyline(String id) async {
    removedPolylineIds.add(id);
  }

  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {
    flyToLocations.add(location);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReportsRepository implements ReportsRepository {
  final List<RecoveryReport> _stored = [];
  int insertCallCount = 0;
  int markAsReadCallCount = 0;
  int markAllAsReadCallCount = 0;
  int clearNavigatorLocationCallCount = 0;
  int? lastMarkedId;
  int? lastClearedNavigatorId;

  @override
  Future<List<RecoveryReport>> getAllReports() async =>
      List.unmodifiable(_stored);

  @override
  Future<void> insertReport(RecoveryReport report) async {
    insertCallCount++;
    _stored.add(report);
  }

  @override
  Future<void> markAsRead(int id) async {
    markAsReadCallCount++;
    lastMarkedId = id;
  }

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCallCount++;
  }

  @override
  Future<void> updateNavigatorLocation(
      int id, double latitude, double longitude) async {}

  @override
  Future<void> clearNavigatorLocation(int id) async {
    clearNavigatorLocationCallCount++;
    lastClearedNavigatorId = id;
  }

  @override
  Future<void> updateRouteGeometry(int id, String geometryJson) async {}

  @override
  Future<void> deleteReport(int id) async {
    _stored.removeWhere((r) => r.id == id);
  }
}

class FakeRemoteReportSource implements RemoteReportSource {
  List<RecoveryReport> remoteReports = const [];
  Map<String, NavigatorUpdate?> navigatorStatesByEntityId = {};
  int fetchRemoteCallCount = 0;
  int fetchNavigatorStateCallCount = 0;

  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() async {
    fetchRemoteCallCount++;
    return remoteReports;
  }

  @override
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId) async {
    fetchNavigatorStateCallCount++;
    return navigatorStatesByEntityId[entityId];
  }

  @override
  Future<List<LatLng>?> fetchEntityGeometry(String entityId) async => null;

  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() async => const {};
}

class _NoopEntityPort implements RecoveryEntityPort {
  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async =>
      true;

  @override
  Future<bool> publishNavigatorEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng vehiclePosition,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async =>
      true;

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async => true;
}

class _NoopMeshPort implements MeshBroadcasterPort {
  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async =>
      true;

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async => true;

  @override
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {}

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {}
}

class FakePublishRecoveryDeletion extends PublishRecoveryDeletion {
  int publishDeletionCallCount = 0;
  String? lastDeletedEntityId;
  PublishResult outcome = const PublishResult(latticeOk: true, meshOk: true);

  FakePublishRecoveryDeletion()
      : super(entityPort: _NoopEntityPort(), meshPort: _NoopMeshPort());

  @override
  Future<PublishResult> call({required String entityId}) async {
    publishDeletionCallCount++;
    lastDeletedEntityId = entityId;
    return outcome;
  }
}

class FakeNavigationViewModel extends ChangeNotifier
    implements NavigationViewModel {
  @override
  LatLng? currentLocation;

  @override
  String activeRouteId = '';

  @override
  String? navigatingEntityId;

  @override
  RecoveryReport? navigatingReport;

  RecoveryReport? navigateToResult;
  bool clearNavigationCalled = false;
  final List<RecoveryReport> navigateToReports = [];

  @override
  bool get isNavigating => navigatingEntityId != null;

  @override
  bool get hasLocation => currentLocation != null;

  @override
  Future<RecoveryReport?> navigateTo(RecoveryReport report) async {
    navigateToReports.add(report);
    return navigateToResult;
  }

  @override
  void clearNavigation() {
    clearNavigationCalled = true;
    activeRouteId = '';
    navigatingEntityId = null;
    navigatingReport = null;
  }

  @override
  void stopNavigation() {
    navigatingEntityId = null;
    navigatingReport = null;
  }

  @override
  void broadcastNavigationStopped() {}

  @override
  Future<void> refreshLocation() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReportsViewModel createVm({
  required FakeMessagingService messaging,
  required FakeMapService map,
  required FakeReportsRepository repo,
  required FakeNavigationViewModel navVm,
  FakeRemoteReportSource? source,
  FakePublishRecoveryDeletion? deletion,
  SnackBarService? snackBarService,
}) {
  final src = source ?? FakeRemoteReportSource();
  final del = deletion ?? FakePublishRecoveryDeletion();
  return ReportsViewModel(
    messaging,
    repo,
    ParseIncomingReport(),
    ParseIncomingDeletion(),
    ViewReportOnMap(map),
    ParseNavigatorUpdate(),
    PollRouteGeometry(src, repo),
    SyncRemoteReports(src, repo),
    SyncLocalReportsToLattice(src, _NoopEntityPort()),
    SyncNavigatorStates(src),
    map,
    navVm,
    del,
    snackBarService: snackBarService,
  );
}

sdk.IncomingMessage makeIncomingRecoveryMessage({
  String fromCallsign = 'Alpha',
  String? entityId,
  String bumperNumber = 'HQ-42',
  String issue = 'flat tire',
  String recoveryType = 'Wrecker',
  double latitude = 33.0,
  double longitude = -84.0,
  DateTime? timestamp,
}) {
  final ts = timestamp ?? DateTime.utc(2026, 3, 24, 12, 0);
  final id = entityId ?? 'entity-${DateTime.now().microsecondsSinceEpoch}';
  return sdk.IncomingMessage(
    id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
    fromPeerId: 'peer-1',
    fromCallsign: fromCallsign,
    payload: jsonEncode({
      'type': 'recovery_request',
      'entityId': id,
      'bumperNumber': bumperNumber,
      'issue': issue,
      'recoveryType': recoveryType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': ts.toIso8601String(),
    }),
    receivedAt: DateTime.now(),
  );
}

RecoveryReport makeReport({
  int? id,
  String fromCallsign = 'Ghost',
  String bumperNumber = 'HQ-42',
  bool isRead = false,
  bool isOutgoing = false,
}) {
  return RecoveryReport(
    id: id,
    fromCallsign: fromCallsign,
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: 'Wrecker',
    latitude: 33.0,
    longitude: -84.0,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
    isRead: isRead,
    isOutgoing: isOutgoing,
  );
}

void main() {
  late FakeMessagingService messaging;
  late FakeMapService map;
  late FakeReportsRepository repo;
  late FakeNavigationViewModel navVm;
  late ReportsViewModel vm;

  setUp(() async {
    messaging = FakeMessagingService();
    map = FakeMapService();
    repo = FakeReportsRepository();
    navVm = FakeNavigationViewModel();
    vm = createVm(messaging: messaging, map: map, repo: repo, navVm: navVm);
    await Future.delayed(Duration.zero);
  });

  tearDown(() {
    vm.dispose();
    messaging.dispose();
  });

  group('initial state', () {
    test('reports list is empty when repo is empty', () {
      expect(vm.reports, isEmpty);
    });

    test('unreadCount is 0 initially', () {
      expect(vm.unreadCount.value, 0);
    });
  });

  group('distanceTo', () {
    test('returns null when navigation view model has no location', () {
      final report = makeReport();
      expect(vm.distanceTo(report), isNull);
    });

    test('returns formatted distance when location is set', () {
      navVm.currentLocation = const LatLng(33.0, -84.0);

      final report = RecoveryReport(
        fromCallsign: 'X',
        bumperNumber: 'Y',
        issue: 'z',
        recoveryType: 'Wrecker',
        latitude: 34.0,
        longitude: -85.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final distance = vm.distanceTo(report);
      expect(distance, isNotNull);
      expect(distance!, endsWith(' km'));
    });

    test('returns 0.00 km for same location', () {
      navVm.currentLocation = const LatLng(33.0, -84.0);
      final report = makeReport();
      expect(vm.distanceTo(report), '0.00 km');
    });
  });

  group('incoming messages', () {
    test('adds incoming recovery_request to reports', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);
      expect(vm.reports.length, 1);
      expect(vm.reports.first.fromCallsign, 'Alpha');
    });

    test('incoming report is unread and not outgoing', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);
      expect(vm.reports.first.isRead, isFalse);
      expect(vm.reports.first.isOutgoing, isFalse);
    });

    test('incoming report increments unreadCount', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);
      expect(vm.unreadCount.value, 1);
    });

    test('multiple incoming messages increment unread count', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'A'));
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'B'));
      await Future.delayed(Duration.zero);
      expect(vm.unreadCount.value, 2);
    });

    test('incoming report is persisted to repository', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);
      expect(repo.insertCallCount, 1);
    });

    test('ignores messages without recovery_request type', () async {
      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-1',
        fromPeerId: 'peer-1',
        fromCallsign: 'Alpha',
        payload: jsonEncode({'type': 'chat', 'text': 'hello'}),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(vm.reports, isEmpty);
    });

    test('ignores malformed JSON payloads', () async {
      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-1',
        fromPeerId: 'peer-1',
        fromCallsign: 'Alpha',
        payload: 'not json',
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(vm.reports, isEmpty);
    });

    test('ignores messages with missing required fields', () async {
      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-1',
        fromPeerId: 'peer-1',
        fromCallsign: 'Alpha',
        payload: jsonEncode({'type': 'recovery_request'}),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(vm.reports, isEmpty);
    });

    test('inserts at beginning of list', () async {
      vm.reports.insert(
          0, makeReport(bumperNumber: 'FIRST', isOutgoing: true, isRead: true));
      messaging
          .emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'SECOND'));
      await Future.delayed(Duration.zero);
      expect(vm.reports.first.bumperNumber, 'SECOND');
    });
  });

  group('navigator update messages', () {
    test('updates matching outgoing report with navigator location', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-1',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(vm.reports.first.navigatorLatitude, 34.5);
      expect(vm.reports.first.navigatorLongitude, -85.5);
    });

    test('ignores navigator update for non-outgoing reports', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: false,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-2',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(vm.reports.first.navigatorLatitude, isNull);
    });

    test('ignores navigator update with no matching entityId', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-999');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-3',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-other',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(vm.reports.first.navigatorLatitude, isNull);
    });

    test('notifies listeners on navigator update', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-4',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(notifyCount, 1);
    });

    test('places responder marker on map', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-5',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(map.addedMarkerLabels, contains('Responder Moving to--> HQ-42 '));
    });

    test('draws route geometry on map when present', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-6',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'routeGeometry': [
            [34.5, -85.5],
            [33.5, -84.5],
            [33.0, -84.0],
          ],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(map.addedPolylineIds.length, 1);
      expect(vm.reports.first.routeGeometry, isNotNull);
      expect(vm.reports.first.routeGeometry!.length, 3);
    });

    test('clears navigator data on navigation_stopped message', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(
          entityId: 'entity-123',
          navigatorLatitude: 34.5,
          navigatorLongitude: -85.5);
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-stop-1',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigation_stopped',
          'entityId': 'entity-123',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(vm.reports.first.navigatorLatitude, isNull);
      expect(vm.reports.first.navigatorLongitude, isNull);
      expect(vm.reports.first.routeGeometry, isNull);
    });

    test('clears responder marker on navigation_stopped', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-nav-place',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigator_update',
          'entityId': 'entity-123',
          'navigatorLatitude': 34.5,
          'navigatorLongitude': -85.5,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(map.addedMarkerLabels.length, 1);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-stop-2',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigation_stopped',
          'entityId': 'entity-123',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(map.removedMarkerIds.length, 1);
      expect(vm.responderMarkerId, isNull);
    });

    test('clears navigator location in database on navigation_stopped',
        () async {
      final report = makeReport(
        id: 7,
        isOutgoing: true,
      ).copyWith(
          entityId: 'entity-123',
          navigatorLatitude: 34.5,
          navigatorLongitude: -85.5);
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-stop-3',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigation_stopped',
          'entityId': 'entity-123',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(repo.clearNavigatorLocationCallCount, 1);
      expect(repo.lastClearedNavigatorId, 7);
    });

    test('ignores navigation_stopped for non-outgoing reports', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: false,
      ).copyWith(
          entityId: 'entity-123',
          navigatorLatitude: 34.5,
          navigatorLongitude: -85.5);
      vm.reports.add(report);

      messaging.emitMessage(sdk.IncomingMessage(
        id: 'msg-stop-4',
        fromPeerId: 'peer-2',
        fromCallsign: 'Rescuer',
        payload: jsonEncode({
          'type': 'navigation_stopped',
          'entityId': 'entity-123',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(vm.reports.first.navigatorLatitude, 34.5);
    });

    test('updates responder marker on subsequent updates', () async {
      final report = makeReport(
        id: 1,
        isOutgoing: true,
      ).copyWith(entityId: 'entity-123');
      vm.reports.add(report);

      for (var i = 0; i < 2; i++) {
        messaging.emitMessage(sdk.IncomingMessage(
          id: 'msg-nav-multi-$i',
          fromPeerId: 'peer-2',
          fromCallsign: 'Rescuer',
          payload: jsonEncode({
            'type': 'navigator_update',
            'entityId': 'entity-123',
            'navigatorLatitude': 34.0 - i * 0.5,
            'navigatorLongitude': -85.0,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          receivedAt: DateTime.now(),
        ));
        await Future.delayed(Duration.zero);
      }

      expect(map.addedMarkerLabels.length, 2);
      expect(map.removedMarkerIds.length, 1);
    });
  });

  group('markReportAsRead', () {
    test('marks an unread report as read', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);

      final report = vm.reports.first;
      await vm.markReportAsRead(report);

      expect(vm.reports.first.isRead, isTrue);
    });

    test('decrements unreadCount', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);
      expect(vm.unreadCount.value, 1);

      await vm.markReportAsRead(vm.reports.first);
      expect(vm.unreadCount.value, 0);
    });

    test('is a no-op for already-read report', () async {
      vm.reports.insert(0, makeReport(isOutgoing: true, isRead: true));
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      await vm.markReportAsRead(vm.reports.first);
      expect(notifyCount, 0);
    });

    test('calls repository.markAsRead when report has id', () async {
      final reportWithId = makeReport(id: 42);
      repo._stored.add(reportWithId);
      vm.dispose();
      messaging.dispose();
      messaging = FakeMessagingService();
      vm = createVm(messaging: messaging, map: map, repo: repo, navVm: navVm);
      await Future.delayed(Duration.zero);

      await vm.markReportAsRead(vm.reports.first);
      expect(repo.markAsReadCallCount, 1);
      expect(repo.lastMarkedId, 42);
    });

    test('notifies listeners', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.markReportAsRead(vm.reports.first);
      expect(notifyCount, 1);
    });
  });

  group('markAllAsRead', () {
    test('marks all unread reports as read', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'A'));
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'B'));
      await Future.delayed(Duration.zero);
      expect(vm.unreadCount.value, 2);

      await vm.markAllAsRead();
      expect(vm.unreadCount.value, 0);
      expect(vm.reports.every((r) => r.isRead), isTrue);
    });

    test('calls repository.markAllAsRead', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage());
      await Future.delayed(Duration.zero);

      await vm.markAllAsRead();
      expect(repo.markAllAsReadCallCount, 1);
    });

    test('is a no-op when all reports are already read', () async {
      vm.reports.insert(0, makeReport(isOutgoing: true, isRead: true));
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      await vm.markAllAsRead();
      expect(notifyCount, 0);
      expect(repo.markAllAsReadCallCount, 0);
    });

    test('is a no-op on empty list', () async {
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.markAllAsRead();
      expect(notifyCount, 0);
    });
  });

  group('viewReport', () {
    test('adds marker on map', () async {
      final report = makeReport();
      await vm.viewReport(report);
      expect(map.addedMarkerLabels, ['HQ-42 - Wrecker']);
    });

    test('flies to report location', () async {
      final report = makeReport();
      await vm.viewReport(report);
      expect(map.flyToLocations.length, 1);
      expect(map.flyToLocations.first.latitude, 33.0);
    });

    test('adds markers for each viewed report', () async {
      await vm.viewReport(makeReport(bumperNumber: 'A'));
      await vm.viewReport(makeReport(bumperNumber: 'B'));
      expect(map.addedMarkerLabels.length, 2);
    });

    test('clears navigation state via NavigationViewModel', () async {
      await vm.viewReport(makeReport());
      expect(navVm.clearNavigationCalled, isTrue);
    });
  });

  group('navigateTo', () {
    test('delegates to NavigationViewModel', () async {
      final report = makeReport();
      navVm.navigateToResult = report.copyWith(
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      );

      vm.reports.add(report);
      await vm.navigateTo(report);

      expect(navVm.navigateToReports.length, 1);
      expect(navVm.navigateToReports.first.bumperNumber, 'HQ-42');
    });

    test('updates report in list with result from NavigationViewModel',
        () async {
      final report = makeReport();
      navVm.navigateToResult = report.copyWith(
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      );

      vm.reports.add(report);
      await vm.navigateTo(report);

      expect(vm.reports.first.navigatorLatitude, 34.0);
      expect(vm.reports.first.navigatorLongitude, -85.0);
    });

    test('does nothing when NavigationViewModel returns null', () async {
      navVm.navigateToResult = null;
      final report = makeReport();
      vm.reports.add(report);

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.navigateTo(report);

      expect(notifyCount, 0);
      expect(vm.reports.first.navigatorLatitude, isNull);
    });

    test('notifies listeners on success', () async {
      final report = makeReport();
      navVm.navigateToResult = report.copyWith(
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      );

      vm.reports.add(report);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.navigateTo(report);

      expect(notifyCount, 1);
    });
  });

  group('deleteReport', () {
    test('publishes deletion for outgoing reports with entity id', () async {
      final deletion = FakePublishRecoveryDeletion();
      vm.dispose();
      messaging.dispose();
      messaging = FakeMessagingService();
      vm = createVm(
        messaging: messaging,
        map: map,
        repo: repo,
        navVm: navVm,
        deletion: deletion,
      );
      await Future.delayed(Duration.zero);

      final report =
          makeReport(id: 1, isOutgoing: true).copyWith(entityId: 'entity-1');
      vm.reports.add(report);

      await vm.deleteReport(report);

      expect(deletion.publishDeletionCallCount, 1);
      expect(deletion.lastDeletedEntityId, 'entity-1');
    });

    test('does not publish deletion for non-outgoing reports', () async {
      final deletion = FakePublishRecoveryDeletion();
      vm.dispose();
      messaging.dispose();
      messaging = FakeMessagingService();
      vm = createVm(
        messaging: messaging,
        map: map,
        repo: repo,
        navVm: navVm,
        deletion: deletion,
      );
      await Future.delayed(Duration.zero);

      final report = makeReport(id: 1).copyWith(entityId: 'entity-1');
      vm.reports.add(report);

      await vm.deleteReport(report);

      expect(deletion.publishDeletionCallCount, 0);
    });
  });

  group('navigatorProgress', () {
    test('returns null when no navigator location', () {
      final report = makeReport();
      expect(vm.navigatorProgress(report), isNull);
    });

    test('returns 1.0 when navigator is at the vehicle', () {
      final report = makeReport().copyWith(
        navigatorLatitude: 33.0,
        navigatorLongitude: -84.0,
      );
      expect(vm.navigatorProgress(report), 1.0);
    });

    test('returns value between 0 and 1 for distant navigator', () {
      final report = makeReport().copyWith(
        navigatorLatitude: 33.1,
        navigatorLongitude: -84.0,
      );
      final progress = vm.navigatorProgress(report)!;
      expect(progress, greaterThan(0.0));
      expect(progress, lessThan(1.0));
    });

    test('returns 1.0 when navigator is within 100m', () {
      final report = makeReport().copyWith(
        navigatorLatitude: 33.0005,
        navigatorLongitude: -84.0005,
      );
      expect(vm.navigatorProgress(report), 1.0);
    });
  });

  group('navigatorDistanceRemaining', () {
    test('returns null when no navigator location', () {
      final report = makeReport();
      expect(vm.navigatorDistanceRemaining(report), isNull);
    });

    test('returns meters for short distances', () {
      final report = makeReport().copyWith(
        navigatorLatitude: 33.003,
        navigatorLongitude: -84.003,
      );
      final result = vm.navigatorDistanceRemaining(report)!;
      expect(result, endsWith(' m away'));
    });

    test('returns km for long distances', () {
      final report = makeReport().copyWith(
        navigatorLatitude: 34.0,
        navigatorLongitude: -85.0,
      );
      final result = vm.navigatorDistanceRemaining(report)!;
      expect(result, endsWith(' km away'));
    });
  });

  group('load from database', () {
    test('loads existing reports on construction', () async {
      final preExisting = makeReport(id: 1, bumperNumber: 'PRE');
      repo._stored.add(preExisting);

      vm.dispose();
      messaging.dispose();
      messaging = FakeMessagingService();
      vm = createVm(messaging: messaging, map: map, repo: repo, navVm: navVm);
      await Future.delayed(Duration.zero);

      expect(vm.reports.any((r) => r.bumperNumber == 'PRE'), isTrue);
    });

    test('sets unread count from loaded reports', () async {
      repo._stored.add(makeReport(id: 1, isRead: false));
      repo._stored.add(makeReport(id: 2, isRead: true));

      vm.dispose();
      messaging.dispose();
      messaging = FakeMessagingService();
      vm = createVm(messaging: messaging, map: map, repo: repo, navVm: navVm);
      await Future.delayed(Duration.zero);

      expect(vm.unreadCount.value, 1);
    });
  });

  group('yourReports and externalReports', () {
    test('yourReports returns only outgoing reports', () {
      vm.reports.addAll([
        makeReport(bumperNumber: 'A', isOutgoing: true),
        makeReport(bumperNumber: 'B', isOutgoing: false),
        makeReport(bumperNumber: 'C', isOutgoing: true),
      ]);
      final yours = vm.yourReports;
      expect(yours.length, 2);
      expect(yours.every((r) => r.isOutgoing), isTrue);
    });

    test('externalReports returns only incoming reports', () {
      vm.reports.addAll([
        makeReport(bumperNumber: 'A', isOutgoing: true),
        makeReport(bumperNumber: 'B', isOutgoing: false),
        makeReport(bumperNumber: 'C', isOutgoing: false),
      ]);
      final external = vm.externalReports;
      expect(external.length, 2);
      expect(external.every((r) => !r.isOutgoing), isTrue);
    });

    test('both lists are empty when reports is empty', () {
      expect(vm.yourReports, isEmpty);
      expect(vm.externalReports, isEmpty);
    });

    test('all reports appear in exactly one filtered list', () {
      vm.reports.addAll([
        makeReport(bumperNumber: 'A', isOutgoing: true),
        makeReport(bumperNumber: 'B', isOutgoing: false),
        makeReport(bumperNumber: 'C', isOutgoing: true),
        makeReport(bumperNumber: 'D', isOutgoing: false),
      ]);
      expect(
          vm.yourReports.length + vm.externalReports.length, vm.reports.length);
    });
  });

  group('unreadCount', () {
    test('excludes outgoing reports from unread count', () {
      vm.reports.insert(0, makeReport(isOutgoing: true, isRead: true));
      vm.updateUnread();
      expect(vm.unreadCount.value, 0);
    });

    test('counts only unread non-outgoing reports', () async {
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'A'));
      messaging.emitMessage(makeIncomingRecoveryMessage(bumperNumber: 'B'));
      await Future.delayed(Duration.zero);

      vm.reports.insert(
          0, makeReport(bumperNumber: 'C', isOutgoing: true, isRead: true));
      vm.updateUnread();
      expect(vm.unreadCount.value, 2);
    });
  });

  group('distanceToKm', () {
    test('returns null when no location', () {
      expect(vm.distanceToKm(makeReport()), isNull);
    });

    test('returns 0.0 for same location', () {
      navVm.currentLocation = const LatLng(33.0, -84.0);
      expect(vm.distanceToKm(makeReport()), closeTo(0.0, 0.001));
    });

    test('returns positive value for different location', () {
      navVm.currentLocation = const LatLng(33.0, -84.0);
      final report = RecoveryReport(
        fromCallsign: 'X',
        bumperNumber: 'Y',
        issue: 'z',
        recoveryType: 'Wrecker',
        latitude: 34.0,
        longitude: -85.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final km = vm.distanceToKm(report);
      expect(km, isNotNull);
      expect(km!, greaterThan(0));
    });
  });

  group('DistanceBracket.fromKm', () {
    test('null returns unknown', () {
      expect(DistanceBracket.fromKm(null), DistanceBracket.unknown);
    });

    test('0.5 returns under1km', () {
      expect(DistanceBracket.fromKm(0.5), DistanceBracket.under1km);
    });

    test('1.5 returns from1to2km', () {
      expect(DistanceBracket.fromKm(1.5), DistanceBracket.from1to2km);
    });

    test('3.0 returns from2to5km', () {
      expect(DistanceBracket.fromKm(3.0), DistanceBracket.from2to5km);
    });

    test('7.0 returns from5to10km', () {
      expect(DistanceBracket.fromKm(7.0), DistanceBracket.from5to10km);
    });

    test('15.0 returns from10to20km', () {
      expect(DistanceBracket.fromKm(15.0), DistanceBracket.from10to20km);
    });

    test('25.0 returns over20km', () {
      expect(DistanceBracket.fromKm(25.0), DistanceBracket.over20km);
    });

    test('boundary 1.0 returns from1to2km', () {
      expect(DistanceBracket.fromKm(1.0), DistanceBracket.from1to2km);
    });

    test('boundary 0.0 returns under1km', () {
      expect(DistanceBracket.fromKm(0.0), DistanceBracket.under1km);
    });
  });

  group('groupedExternalReports', () {
    test('returns empty map when no reports', () {
      final grouped = vm.groupedExternalReports;
      for (final bracket in DistanceBracket.values) {
        expect(grouped[bracket], isEmpty);
      }
    });

    test('groups reports into correct brackets', () {
      navVm.currentLocation = const LatLng(33.0, -84.0);

      vm.reports.add(makeReport(bumperNumber: 'NEAR'));

      vm.reports.add(RecoveryReport(
        fromCallsign: 'Far',
        bumperNumber: 'FAR',
        issue: 'engine',
        recoveryType: 'Wrecker',
        latitude: 34.0,
        longitude: -85.0,
        timestamp: DateTime.utc(2026, 1, 1),
      ));

      final grouped = vm.groupedExternalReports;
      expect(
          grouped[DistanceBracket.under1km]!
              .any((r) => r.bumperNumber == 'NEAR'),
          isTrue);
      expect(
          grouped[DistanceBracket.over20km]!
              .any((r) => r.bumperNumber == 'FAR'),
          isTrue);
    });

    test('excludes outgoing reports', () {
      vm.reports.add(makeReport(isOutgoing: true));
      final grouped = vm.groupedExternalReports;
      final total =
          grouped.values.fold<int>(0, (sum, list) => sum + list.length);
      expect(total, 0);
    });

    test('uses unknown bracket when no location', () {
      vm.reports.add(makeReport());
      final grouped = vm.groupedExternalReports;
      expect(grouped[DistanceBracket.unknown]!.length, 1);
    });
  });

  group('unreadPerBracket', () {
    test('returns zeros when no reports', () {
      final unread = vm.unreadPerBracket;
      for (final bracket in DistanceBracket.values) {
        expect(unread[bracket], 0);
      }
    });

    test('counts unread per bracket', () {
      vm.reports.add(makeReport(bumperNumber: 'A'));
      vm.reports.add(makeReport(bumperNumber: 'B'));

      final unread = vm.unreadPerBracket;
      expect(unread[DistanceBracket.unknown], 2);
    });

    test('excludes read reports', () {
      vm.reports.add(makeReport(bumperNumber: 'A', isRead: true));
      vm.reports.add(makeReport(bumperNumber: 'B', isRead: false));

      final unread = vm.unreadPerBracket;
      expect(unread[DistanceBracket.unknown], 1);
    });

    test('excludes outgoing reports', () {
      vm.reports.add(makeReport(isOutgoing: true));

      final unread = vm.unreadPerBracket;
      final total = unread.values.fold<int>(0, (sum, v) => sum + v);
      expect(total, 0);
    });
  });

  group('markBracketAsRead', () {
    test('marks only unread reports in the given bracket', () async {
      vm.reports.add(makeReport(id: 1, bumperNumber: 'A'));
      vm.reports.add(makeReport(id: 2, bumperNumber: 'B'));
      vm.reports.add(makeReport(id: 3, bumperNumber: 'C', isOutgoing: true));

      await vm.markBracketAsRead(DistanceBracket.unknown);

      expect(vm.reports[0].isRead, isTrue);
      expect(vm.reports[1].isRead, isTrue);
      expect(vm.reports[2].isRead, isFalse);
    });

    test('updates unread count', () async {
      vm.reports.add(makeReport(id: 1));
      vm.reports.add(makeReport(id: 2));
      vm.updateUnread();
      expect(vm.unreadCount.value, 2);

      await vm.markBracketAsRead(DistanceBracket.unknown);
      expect(vm.unreadCount.value, 0);
    });

    test('persists each report to repository', () async {
      vm.reports.add(makeReport(id: 10));
      vm.reports.add(makeReport(id: 20));

      await vm.markBracketAsRead(DistanceBracket.unknown);
      expect(repo.markAsReadCallCount, 2);
    });

    test('is a no-op when no unread reports in bracket', () async {
      vm.reports.add(makeReport(id: 1, isRead: true));

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);
      await vm.markBracketAsRead(DistanceBracket.unknown);

      expect(notifyCount, 0);
    });

    test('does not affect reports in other brackets', () async {
      navVm.currentLocation = const LatLng(33.0, -84.0);

      vm.reports.add(makeReport(id: 1, bumperNumber: 'NEAR'));

      vm.reports.add(RecoveryReport(
        id: 2,
        fromCallsign: 'Far',
        bumperNumber: 'FAR',
        issue: 'engine',
        recoveryType: 'Wrecker',
        latitude: 34.0,
        longitude: -85.0,
        timestamp: DateTime.utc(2026, 1, 1),
      ));

      await vm.markBracketAsRead(DistanceBracket.under1km);

      expect(vm.reports[0].isRead, isTrue);
      expect(vm.reports[1].isRead, isFalse);
    });
  });
}
