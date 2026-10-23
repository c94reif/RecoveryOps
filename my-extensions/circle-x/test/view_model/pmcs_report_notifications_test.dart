import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/map/sdk_report_map_adapter.dart';
import 'package:circle_x/data/services/delivery/sdk_report_message_source.dart';
import 'package:circle_x/domain/reporting/entities/maintainer_review.dart';
import 'package:circle_x/domain/catalog/entities/pmcs_phase.dart';
import 'package:circle_x/domain/profile/entities/profile.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:circle_x/domain/map/usecases/show_report_on_map.dart';
import 'package:circle_x/domain/delivery/usecases/publish_pmcs_deletion.dart';
import 'package:circle_x/domain/delivery/usecases/parse_incoming_deletion.dart';
import 'package:circle_x/domain/delivery/usecases/parse_incoming_report.dart';
import 'package:circle_x/domain/delivery/usecases/sync_local_reports_to_lattice.dart';
import 'package:circle_x/domain/delivery/usecases/sync_remote_reports.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../support/fake_pmcs_notifications.dart';
import '../support/fakes.dart';
import 'reports_view_model_test.dart' show FakeMessagingService, FakeMapService;

/// Mirrors SQLite's insert-or-ignore behavior and preserves local ownership.
class UniqueNotificationReports extends FakeReportsRepository {
  @override
  Future<PmcsReport> insertReport(PmcsReport report) async {
    if (withdrawnIds.contains(report.entityId)) {
      return super.insertReport(report);
    }
    final existing =
        reports.where((row) => row.entityId == report.entityId).firstOrNull;
    return existing ?? await super.insertReport(report);
  }
}

class GatedNotificationBaseline extends UniqueNotificationReports {
  final entered = Completer<void>();
  final release = Completer<void>();
  var reads = 0;

  @override
  Future<List<PmcsReport>> getAllReports() async {
    final snapshot = await super.getAllReports();
    if (++reads == 1) {
      entered.complete();
      await release.future;
    }
    return snapshot;
  }
}

void main() {
  const codec = PmcsReportCodec();
  late FakeMessagingService messaging;
  late UniqueNotificationReports repository;
  late FakeProfileRepository profiles;
  late FakeRemoteReportSource remote;
  late FakePmcsEntityPort entity;
  late FakeMeshBroadcaster mesh;
  late FakeQueueWorker worker;
  late FakeQueuedSubmissionsRepository queue;
  late FakePmcsNotifications notifications;
  late DeliveryCoordinator delivery;
  ReportsViewModel? model;

  setUp(() {
    messaging = FakeMessagingService();
    repository = UniqueNotificationReports();
    profiles = FakeProfileRepository(
        const Profile(uic: 'WJ8TAA', unitName: 'Alpha', followedUnits: [
      FollowedUnit(uic: 'WAB4C0', name: 'Bravo'),
    ]));
    remote = FakeRemoteReportSource();
    entity = FakePmcsEntityPort();
    mesh = FakeMeshBroadcaster();
    worker = FakeQueueWorker();
    queue = FakeQueuedSubmissionsRepository();
    notifications = FakePmcsNotifications();
    model = null;
  });
  tearDown(() async {
    await model?.syncInFlight;
    model?.dispose();
    await messaging.close();
    await delivery.dispose();
  });

  Future<ReportsViewModel> start() async {
    delivery = DeliveryCoordinator(reportsRepository: repository);
    final reports = ReportsViewModel(
      SdkReportMessageSource(messaging),
      repository,
      ParseIncomingReport(codec),
      ParseIncomingDeletion(codec),
      SyncRemoteReports(remote, repository),
      SyncLocalReportsToLattice(remote, entity,
          reportsRepository: repository,
          queuedRepository: queue,
          queueWorker: worker,
          codec: codec,
          delivery: delivery),
      ShowReportOnMap(SdkReportMapAdapter(FakeMapService())),
      PublishPmcsDeletion(
          codec: codec,
          entityPort: entity,
          meshPort: mesh,
          queueWorker: worker,
          repository: repository,
          delivery: delivery,
          queuedRepository: queue,
          transaction: FakeTransactionRunner()),
      worker,
      syncOnStart: false,
      profileRepository: profiles,
      queuedRepository: queue,
      delivery: delivery,
      notificationPort: notifications,
    );
    model = reports;
    await Future<void>.delayed(Duration.zero);
    return reports;
  }

  Future<void> settle(ReportsViewModel reports) async {
    await Future<void>.delayed(Duration.zero);
    await reports.syncRemoteLatticeReports();
    await reports.reportNotifier.settled;
  }

  test(
      'peer and store arrivals alert for subscribed units with current aliases',
      () async {
    final reports = await start();
    messaging.emit(codec.encodeReport(buildReport(
        entityId: 'peer',
        uic: 'WAB4C0',
        bumperNumber: 'B-22',
        isOutgoing: false,
        isRead: false)));
    await settle(reports);
    remote.remote = [
      buildReport(entityId: 'store', isOutgoing: false, isRead: false),
      buildReport(
          entityId: 'other', uic: 'WOTHER', isOutgoing: false, isRead: false),
    ];
    remote.knownIds = {'peer', 'store', 'other'};
    await settle(reports);
    expect(
        notifications.posted.map((alert) => alert.reportId), ['peer', 'store']);
    expect(notifications.posted.first.body, contains('Bravo (WAB4C0)'));
    expect(notifications.posted.last.body, contains('Alpha (WJ8TAA)'));
    expect(repository.reports.map((row) => row.entityId).toSet(),
        {'peer', 'store', 'other'});
    expect(notifications.remembered, {'peer', 'store', 'other'});
    expect(mesh.broadcast, isEmpty);
  });

  test(
      'startup baseline gates alerts while new peer storage and relay continue',
      () async {
    final gated = GatedNotificationBaseline();
    repository = gated;
    await repository.insertReport(
        buildReport(entityId: 'old', isOutgoing: false, isRead: false));
    final reports = await start();
    await gated.entered.future;
    await reports.storeIncomingReport(
        buildReport(entityId: 'fresh', isOutgoing: false, isRead: false));
    await reports.syncRemoteLatticeReports();
    expect(repository.reports.map((row) => row.entityId).toSet(),
        {'old', 'fresh'});
    expect(entity.published.map((row) => row.entityId), contains('fresh'));
    expect(notifications.posted, isEmpty);
    gated.release.complete();
    await reports.reportNotifier.settled;
    expect(notifications.posted.single.reportId, 'fresh');
    expect(notifications.remembered, {'old', 'fresh'});
  });

  test('concurrent peer and store copies generate one notification', () async {
    final reports = await start();
    final incoming =
        buildReport(entityId: 'same', isOutgoing: false, isRead: false);
    remote.remote = [incoming];
    remote.knownIds = {'same'};
    await Future.wait([
      reports.storeIncomingReport(incoming),
      reports.syncRemoteLatticeReports(),
    ]);
    await settle(reports);
    expect(repository.reports, hasLength(1));
    expect(notifications.attempts, ['same']);
    expect(notifications.posted, hasLength(1));
  });

  test('echoed outgoing and already read reports use their persisted state',
      () async {
    final reports = await start();
    await repository.insertReport(buildReport(entityId: 'mine', isRead: false));
    await repository
        .insertReport(buildReport(entityId: 'read', isOutgoing: false));
    await reports.storeIncomingReport(
        buildReport(entityId: 'mine', isOutgoing: false, isRead: false));
    await reports.storeIncomingReport(
        buildReport(entityId: 'read', isOutgoing: false, isRead: false));
    await settle(reports);
    expect(notifications.posted, isEmpty);
    expect(notifications.remembered, {'mine', 'read'});
    expect(repository.reports.first.isOutgoing, isTrue);
    expect(repository.reports.last.isRead, isTrue);
  });

  for (final action in ['read', 'read all', 'delete']) {
    test('$action suppresses an incoming alert waiting behind a phone request',
        () async {
      final reports = await start();
      notifications.showGate = Completer<void>();
      await reports.storeIncomingReport(
          buildReport(entityId: 'first', isOutgoing: false, isRead: false));
      await Future<void>.delayed(Duration.zero);
      expect(notifications.attempts, ['first']);
      await reports.storeIncomingReport(
          buildReport(entityId: 'pending', isOutgoing: false, isRead: false));
      final pending = repository.reports
          .singleWhere((report) => report.entityId == 'pending');

      switch (action) {
        case 'read':
          await reports.markReportAsRead(pending);
          expect(repository.readIds, [pending.id]);
        case 'read all':
          await reports.markAllAsRead();
          expect(repository.markedAll, isTrue);
        case 'delete':
          await reports.deleteReport(pending);
          expect(repository.deletedIds, [pending.id]);
      }

      // The local action must finish without waiting for the native request.
      expect(notifications.showGate!.isCompleted, isFalse);
      notifications.showGate!.complete();
      await settle(reports);
      expect(notifications.attempts, ['first']);
      expect(notifications.posted.single.reportId, 'first');
      expect(notifications.remembered, {'first', 'pending'});
    });
  }

  test('review arriving first alerts once for its newly restored original PMCS',
      () async {
    final reports = await start();
    final review = buildReport(
        entityId: 'review',
        isOutgoing: false,
        isRead: false,
        maintainerReview: MaintainerReview(
            sourceReportId: 'original',
            faults: const [
              FaultReview(
                  itemId: 'engine', phase: PmcsPhase.before, verified: true)
            ],
            signature: buildSignature()));
    await reports.storeIncomingReport(review);
    await settle(reports);
    await reports.storeIncomingReport(
        buildReport(entityId: 'original', isOutgoing: false, isRead: false));
    await settle(reports);
    expect(notifications.posted.single.reportId, 'original');
    expect(notifications.remembered, {'original', 'review'});
    expect(repository.reports, hasLength(2));
  });

  test(
      'native notification failures cannot lose received reports or their relay',
      () async {
    final reports = await start();
    notifications.failShow = true;
    notifications.failRemember = true;
    await reports.storeIncomingReport(
        buildReport(entityId: 'received', isOutgoing: false, isRead: false));
    await settle(reports);
    expect(repository.reports.single.entityId, 'received');
    expect(entity.published.map((row) => row.entityId), contains('received'));
    expect(reports.externalReports.single.entityId, 'received');
    expect(notifications.posted, isEmpty);
  });

  test(
      'peer withdrawal followed by a late report is remembered without alerting',
      () async {
    final reports = await start();
    await reports.applyRemoteDeletion('withdrawn');
    await reports.storeIncomingReport(
        buildReport(entityId: 'withdrawn', isOutgoing: false, isRead: false));
    await settle(reports);
    expect(repository.reports, isEmpty);
    expect(notifications.posted, isEmpty);
    expect(notifications.remembered, {'withdrawn'});
  });
}
