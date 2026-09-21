import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/usecases/map/show_report_on_map.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:ivy_pulse/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:ivy_pulse/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../support/fakes.dart';

/// Stands in for the host mesh radio. Nothing but [onMessageReceived] is
/// reachable from the view model, so the rest of the interface goes to
/// [noSuchMethod] and throws loudly if it is ever touched.
class FakeMessagingService implements sdk.MessagingService {
  final StreamController<sdk.IncomingMessage> controller =
      StreamController<sdk.IncomingMessage>.broadcast();

  @override
  Stream<sdk.IncomingMessage> get onMessageReceived => controller.stream;

  void emit(String payload, {String fromCallsign = 'BRAVO 2'}) {
    controller.add(sdk.IncomingMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      fromPeerId: 'peer-1',
      fromCallsign: fromCallsign,
      payload: payload,
      receivedAt: DateTime.utc(2026, 3, 24, 9),
    ));
  }

  Future<void> close() => controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMapService implements sdk.MapService {
  final List<String> addedLabels = [];
  final List<String> removedMarkerIds = [];
  int markerCounter = 0;

  @override
  Future<String> addMarker(
    sdk.LatLng location, {
    String? label,
    String? color,
    sdk.MarkerIcon? icon,
    sdk.MarkerDisposition? disposition,
  }) async {
    addedLabels.add(label ?? '');
    return 'marker-${markerCounter++}';
  }

  @override
  Future<void> removeMarker(String id) async {
    removedMarkerIds.add(id);
  }

  @override
  Future<void> flyTo(sdk.LatLng location, {double? zoom}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The shared fake counts what it was handed; the badge needs a number the
/// test can set without building queued submissions it never inspects.
class CountingQueueWorker extends FakeQueueWorker {
  int pending = 0;
  Object? throwOnCount;

  @override
  Future<int> pendingCount() async {
    if (throwOnCount != null) throw throwOnCount!;
    return pending;
  }
}

void main() {
  late FakeMessagingService messaging;
  late FakeReportsRepository repository;
  late FakeReportCodec codec;
  late FakeRemoteReportSource remoteSource;
  late FakePmcsEntityPort entityPort;
  late FakeMeshBroadcaster meshPort;
  late CountingQueueWorker queueWorker;
  late FakeMapService mapService;
  late ReportsViewModel viewModel;
  late bool disposed;

  /// One turn of the event loop — long enough for the constructor's database
  /// load and every un-awaited follow-up to settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> start() async {
    viewModel = ReportsViewModel(
      messaging,
      repository,
      ParseIncomingReport(codec),
      ParseIncomingDeletion(codec),
      SyncRemoteReports(remoteSource, repository),
      SyncLocalReportsToLattice(remoteSource, entityPort),
      ShowReportOnMap(mapService),
      PublishPmcsDeletion(entityPort: entityPort, meshPort: meshPort),
      queueWorker,
    );
    await settle();
  }

  setUp(() {
    messaging = FakeMessagingService();
    repository = FakeReportsRepository();
    codec = FakeReportCodec();
    remoteSource = FakeRemoteReportSource();
    entityPort = FakePmcsEntityPort();
    meshPort = FakeMeshBroadcaster();
    queueWorker = CountingQueueWorker();
    mapService = FakeMapService();
    disposed = false;
    SnackBarService.instance.queue.clear();
  });

  tearDown(() async {
    if (!disposed) viewModel.dispose();
    await messaging.close();
    SnackBarService.instance.queue.clear();
  });

  group('loading stored reports', () {
    test('reports already in the database are on screen before any traffic',
        () async {
      repository.reports.addAll([
        buildReport(id: 1, entityId: 'mine-1', isOutgoing: true),
        buildReport(
          id: 2,
          entityId: 'bravo-1',
          isOutgoing: false,
          isRead: false,
        ),
      ]);

      await start();

      expect(
        viewModel.reports.map((r) => r.entityId),
        ['mine-1', 'bravo-1'],
      );
      expect(viewModel.unreadCount.value, 1);
    });

    test('an unread report this device sent does not badge the tab', () async {
      repository.reports.add(
        buildReport(id: 1, entityId: 'mine-1', isOutgoing: true, isRead: false),
      );

      await start();

      expect(viewModel.unreadCount.value, 0);
    });
  });

  group('inbound mesh traffic', () {
    test(
        'a PMCS from another crew is decoded, stored and raises the unread '
        'count', () async {
      await start();
      expect(viewModel.unreadCount.value, 0);

      codec.decodeResult = buildReport(
        entityId: 'bravo-1',
        bumperNumber: 'B-22',
        isOutgoing: false,
        isRead: false,
      );
      messaging.emit('{"type":"ivy_pulse.report"}');
      await settle();

      expect(viewModel.reports.single.entityId, 'bravo-1');
      expect(viewModel.unreadCount.value, 1);
      expect(repository.reports.single.entityId, 'bravo-1');
    });

    test('a newly received PMCS lands at the top of the list', () async {
      repository.reports
          .add(buildReport(id: 1, entityId: 'older', isOutgoing: false));
      await start();

      codec.decodeResult =
          buildReport(entityId: 'newer', isOutgoing: false, isRead: false);
      messaging.emit('{"type":"ivy_pulse.report"}');
      await settle();

      expect(viewModel.reports.first.entityId, 'newer');
    });

    test('a withdrawal from the net removes the matching report', () async {
      repository.reports.add(buildReport(
        id: 7,
        entityId: 'bravo-1',
        isOutgoing: false,
        isRead: false,
      ));
      await start();
      expect(viewModel.unreadCount.value, 1);

      codec.decodeDeletionResult = 'bravo-1';
      messaging.emit('{"type":"ivy_pulse.deletion"}');
      await settle();

      expect(viewModel.reports, isEmpty);
      expect(repository.deletedIds, [7]);
      expect(viewModel.unreadCount.value, 0);
    });

    test('a withdrawal for an entity this device never saw changes nothing',
        () async {
      repository.reports
          .add(buildReport(id: 7, entityId: 'bravo-1', isOutgoing: false));
      await start();

      codec.decodeDeletionResult = 'someone-elses-entity';
      messaging.emit('{"type":"ivy_pulse.deletion"}');
      await settle();

      expect(viewModel.reports, hasLength(1));
      expect(repository.deletedIds, isEmpty);
    });

    test('a payload from another extension is ignored', () async {
      repository.reports.add(buildReport(
        id: 1,
        entityId: 'bravo-1',
        isOutgoing: false,
        isRead: false,
      ));
      await start();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      messaging.emit('{"type":"some.other.extension","body":"not ours"}');
      await settle();

      expect(viewModel.reports, hasLength(1));
      expect(repository.deletedIds, isEmpty);
      expect(notifications, 0);
    });

    test('a mesh report keeps the database id it was stored under', () async {
      // Regression: the parsed report was inserted into the list instead of
      // the stored copy, so its id was null — and both marking read and
      // honouring a withdrawal skip the database without an id. An unread
      // badge and a withdrawn vehicle both came back on the next launch.
      await start();

      codec.decodeResult = buildReport(
        entityId: 'bravo-1',
        isOutgoing: false,
        isRead: false,
      );
      messaging.emit('{"type":"ivy_pulse.report"}');
      await settle();

      expect(repository.reports.single.id, isNotNull);
      expect(viewModel.reports.single.id, repository.reports.single.id);

      codec.decodeResult = null;
      codec.decodeDeletionResult = 'bravo-1';
      messaging.emit('{"type":"ivy_pulse.deletion"}');
      await settle();

      expect(viewModel.reports, isEmpty);
      // The withdrawal now reaches the database too, so the vehicle does not
      // reappear on the next launch.
      expect(repository.deletedIds, hasLength(1));
      expect(repository.reports, isEmpty);
    });
  });

  group('read state', () {
    test('marking one received report read drops the unread count', () async {
      repository.reports.addAll([
        buildReport(id: 1, entityId: 'a', isOutgoing: false, isRead: false),
        buildReport(id: 2, entityId: 'b', isOutgoing: false, isRead: false),
      ]);
      await start();
      expect(viewModel.unreadCount.value, 2);

      await viewModel.markReportAsRead(viewModel.reports.first);

      expect(viewModel.unreadCount.value, 1);
      expect(repository.readIds, [1]);
      expect(viewModel.reports.first.isRead, isTrue);
    });

    test('marking an already read report does not touch the database',
        () async {
      repository.reports
          .add(buildReport(id: 1, entityId: 'a', isOutgoing: false));
      await start();

      await viewModel.markReportAsRead(viewModel.reports.single);

      expect(repository.readIds, isEmpty);
    });

    test('marking all read clears the unread count', () async {
      repository.reports.addAll([
        buildReport(id: 1, entityId: 'a', isOutgoing: false, isRead: false),
        buildReport(id: 2, entityId: 'b', isOutgoing: false, isRead: false),
      ]);
      await start();

      await viewModel.markAllAsRead();

      expect(viewModel.unreadCount.value, 0);
      expect(repository.markedAll, isTrue);
      expect(viewModel.reports.every((r) => r.isRead), isTrue);
    });

    test('marking all read with nothing unread does not hit the database',
        () async {
      repository.reports
          .add(buildReport(id: 1, entityId: 'a', isOutgoing: false));
      await start();

      await viewModel.markAllAsRead();

      expect(repository.markedAll, isFalse);
    });
  });

  group('deleting a report', () {
    test(
        'deleting your own PMCS withdraws it from Lattice and the mesh and '
        'announces the outcome', () async {
      repository.reports
          .add(buildReport(id: 5, entityId: 'mine-1', isOutgoing: true));
      await start();

      await viewModel.deleteReport(viewModel.reports.single);

      expect(viewModel.reports, isEmpty);
      expect(repository.deletedIds, [5]);
      expect(entityPort.deletedIds, ['mine-1']);
      expect(meshPort.deletedIds, ['mine-1']);

      final announcement = SnackBarService.instance.queue.single;
      expect(announcement.message, contains('Lattice: sent'));
      expect(announcement.message, contains('Mesh: sent'));
      expect(announcement.isError, isFalse);
    });

    test('a withdrawal that only half lands is announced as an error',
        () async {
      meshPort.deleteSucceeds = false;
      repository.reports
          .add(buildReport(id: 5, entityId: 'mine-1', isOutgoing: true));
      await start();

      await viewModel.deleteReport(viewModel.reports.single);

      final announcement = SnackBarService.instance.queue.single;
      expect(announcement.message, contains('Lattice: sent'));
      expect(announcement.message, contains('Mesh: FAILED'));
      expect(announcement.isError, isTrue);
    });

    test("deleting a received PMCS never withdraws another crew's entity",
        () async {
      repository.reports.add(buildReport(
        id: 6,
        entityId: 'bravo-1',
        isOutgoing: false,
        isRead: false,
      ));
      await start();

      await viewModel.deleteReport(viewModel.reports.single);

      expect(viewModel.reports, isEmpty);
      expect(repository.deletedIds, [6]);
      expect(entityPort.deletedIds, isEmpty);
      expect(meshPort.deletedIds, isEmpty);
      expect(SnackBarService.instance.queue, isEmpty);
      expect(viewModel.unreadCount.value, 0);
    });
  });

  group('status triage', () {
    test(
        'a RED X report is Not Mission Capable however many other faults it '
        'carries', () async {
      repository.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'deadlined',
          isOutgoing: false,
          faults: [
            buildFault(severity: FaultSeverity.redX),
            buildFault(severity: FaultSeverity.dash),
          ],
        ),
        buildReport(id: 2, entityId: 'clean', isOutgoing: false),
      ]);
      await start();

      final grouped = viewModel.groupedByStatus;

      expect(
        grouped[ReportsViewModel.bucketNotMissionCapable]!
            .map((r) => r.entityId),
        ['deadlined'],
      );
      expect(
        grouped[ReportsViewModel.bucketMissionCapable]!.map((r) => r.entityId),
        ['clean'],
      );
      expect(grouped[ReportsViewModel.bucketLimited], isEmpty);
    });

    test('a CIRCLE X report without a RED X is limited, not deadlined',
        () async {
      repository.reports.add(buildReport(
        id: 1,
        entityId: 'limited',
        isOutgoing: false,
        faults: [buildFault(severity: FaultSeverity.circleX)],
      ));
      await start();

      expect(
        viewModel.bucketFor(viewModel.reports.single),
        ReportsViewModel.bucketLimited,
      );
    });

    test('your own reports are not triaged into the received buckets',
        () async {
      repository.reports.add(buildReport(
        id: 1,
        entityId: 'mine-1',
        isOutgoing: true,
        faults: [buildFault(severity: FaultSeverity.redX)],
      ));
      await start();

      final grouped = viewModel.groupedByStatus;

      expect(grouped.values.expand((g) => g), isEmpty);
      expect(viewModel.yourReports.map((r) => r.entityId), ['mine-1']);
    });
  });

  group('queued submissions', () {
    test('the queued badge reflects what the worker is still holding',
        () async {
      queueWorker.pending = 2;
      await start();

      expect(viewModel.queuedCount.value, 2);

      queueWorker.pending = 0;
      await viewModel.refreshQueuedCount();

      expect(viewModel.queuedCount.value, 0);
    });

    test('a queue worker that throws leaves the badge as it was', () async {
      queueWorker.pending = 3;
      await start();

      queueWorker.throwOnCount = StateError('queue unavailable');
      await viewModel.refreshQueuedCount();

      expect(viewModel.queuedCount.value, 3);
    });
  });

  group('disposal', () {
    test('dispose cancels the mesh subscription and the remote sync timer',
        () async {
      await start();
      final timer = viewModel.remoteSyncTimer;
      expect(timer, isNotNull);
      expect(timer!.isActive, isTrue);

      viewModel.dispose();
      disposed = true;

      expect(timer.isActive, isFalse);

      codec.decodeResult = buildReport(
        entityId: 'after-dispose',
        isOutgoing: false,
        isRead: false,
      );
      messaging.emit('{"type":"ivy_pulse.report"}');
      await settle();

      expect(viewModel.reports, isEmpty);
      expect(repository.reports, isEmpty);
    });
  });
}
