import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/sdk_report_map_adapter.dart';
import 'package:circle_x/data/services/sdk_report_message_source.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';
import 'package:circle_x/domain/usecases/map/show_report_on_map.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_deletion.dart';
import 'package:circle_x/domain/usecases/reporting/parse_incoming_deletion.dart';
import 'package:circle_x/domain/usecases/reporting/parse_incoming_report.dart';
import 'package:circle_x/domain/usecases/reporting/sync_local_reports_to_lattice.dart';
import 'package:circle_x/domain/usecases/reporting/sync_remote_reports.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../support/fakes.dart';
import 'reports_view_model_test.dart' show FakeMessagingService, FakeMapService;

void main() {
  const primary = 'WJ8TAA';
  const followed = 'WAB4C0';
  const other = 'WZZZZZ';
  const codec = PmcsReportCodec();
  late FakeMessagingService messaging;
  late FakeReportsRepository repository;
  late FakeProfileRepository profiles;
  late FakeRemoteReportSource remote;
  late FakePmcsEntityPort entity;
  late FakeMeshBroadcaster mesh;
  late FakeQueueWorker queueWorker;
  late FakeQueuedSubmissionsRepository queue;
  late DeliveryCoordinator delivery;
  ReportsViewModel? model;

  setUp(() {
    messaging = FakeMessagingService();
    repository = FakeReportsRepository();
    profiles = FakeProfileRepository(const Profile(
      uic: primary,
      unitName: 'Alpha Company',
      followedUnits: [FollowedUnit(uic: followed, name: 'Bravo Company')],
    ));
    remote = FakeRemoteReportSource();
    entity = FakePmcsEntityPort();
    mesh = FakeMeshBroadcaster();
    queueWorker = FakeQueueWorker();
    queue = FakeQueuedSubmissionsRepository();
    delivery = DeliveryCoordinator(reportsRepository: repository);
    model = null;
  });

  tearDown(() async {
    await model?.syncInFlight;
    model?.dispose();
    await messaging.close();
    await delivery.dispose();
  });

  Future<ReportsViewModel> start() async {
    final reports = ReportsViewModel(
      SdkReportMessageSource(messaging),
      repository,
      ParseIncomingReport(codec),
      ParseIncomingDeletion(codec),
      SyncRemoteReports(remote, repository),
      SyncLocalReportsToLattice(remote, entity,
          reportsRepository: repository,
          queuedRepository: queue,
          queueWorker: queueWorker,
          codec: codec,
          delivery: delivery),
      ShowReportOnMap(SdkReportMapAdapter(FakeMapService())),
      PublishPmcsDeletion(
          codec: codec,
          entityPort: entity,
          meshPort: mesh,
          queueWorker: queueWorker,
          repository: repository,
          delivery: delivery,
          queuedRepository: queue,
          transaction: FakeTransactionRunner()),
      queueWorker,
      syncOnStart: false,
      profileRepository: profiles,
      queuedRepository: queue,
      snackBarService: const SilentNotificationSink(),
      delivery: delivery,
    );
    model = reports;
    await Future<void>.delayed(Duration.zero);
    return reports;
  }

  Set<String> ids(Iterable<PmcsReport> reports) =>
      reports.map((report) => report.entityId).toSet();

  test('primary and followed units include only their unread external PMCS',
      () async {
    repository.reports.addAll([
      buildReport(
          entityId: 'primary', uic: primary, isOutgoing: false, isRead: false),
      buildReport(
          entityId: 'followed',
          uic: followed,
          isOutgoing: false,
          isRead: false),
      buildReport(entityId: 'read', uic: followed, isOutgoing: false),
      buildReport(
          entityId: 'other', uic: other, isOutgoing: false, isRead: false),
      buildReport(entityId: 'mine', uic: followed, isRead: false),
      buildReport(
          entityId: 'review',
          uic: followed,
          isOutgoing: false,
          isRead: false,
          maintainerReview: MaintainerReview(
            sourceReportId: 'followed',
            faults: const [
              FaultReview(
                  itemId: 'engine', phase: PmcsPhase.before, verified: true)
            ],
            signature: buildSignature(),
          )),
    ]);
    final reports = await start();

    expect(ids(reports.unitReports), {'primary', 'followed', 'read'});
    expect(ids(reports.otherUnitReports), {'other'});
    expect(ids(reports.yourReports), {'mine'});
    expect(reports.unreadCount.value, 2);
    expect(reports.myUic, primary);
    expect(reports.reportUnits.map((unit) => unit.uic), [primary, followed]);
    expect(profiles.profile!.uic, primary);
  });

  test('peer messages and store imports appear for all followed UICs',
      () async {
    final reports = await start();
    messaging.emit(codec.encodeReport(buildReport(
        entityId: 'peer-followed',
        uic: followed,
        isOutgoing: false,
        isRead: false)));
    await Future<void>.delayed(Duration.zero);
    await reports.syncRemoteLatticeReports();
    expect(ids(reports.unitReports), {'peer-followed'});
    expect(ids(entity.published), contains('peer-followed'));

    remote.remote = [
      buildReport(
          entityId: 'store-followed',
          uic: followed,
          isOutgoing: false,
          isRead: false),
      buildReport(
          entityId: 'store-primary',
          uic: primary,
          isOutgoing: false,
          isRead: false),
      buildReport(
          entityId: 'store-other',
          uic: other,
          isOutgoing: false,
          isRead: false),
    ];
    remote.knownIds = {'peer-followed', ...ids(remote.remote)};
    await reports.syncRemoteLatticeReports();

    expect(ids(reports.unitReports),
        {'peer-followed', 'store-followed', 'store-primary'});
    expect(ids(reports.otherUnitReports), {'store-other'});
    expect(reports.unreadCount.value, 3);
    expect(ids(repository.reports),
        {'peer-followed', 'store-followed', 'store-primary', 'store-other'});
    expect(mesh.broadcast, isEmpty);
  });

  test('reloading local unit names notifies immediately without changing UICs',
      () async {
    repository.reports.add(buildReport(
        entityId: 'bravo', uic: followed, isOutgoing: false, isRead: false));
    final reports = await start();
    expect(reports.reportUnits.map((unit) => unit.label),
        ['Alpha Company ($primary)', 'Bravo Company ($followed)']);
    expect(ids(reports.unitReports), {'bravo'});
    var notifications = 0;
    reports.addListener(() => notifications++);

    await profiles.saveProfile(const Profile(
      uic: primary,
      unitName: 'Home Unit',
      followedUnits: [FollowedUnit(uic: followed, name: 'Attached Unit')],
    ));
    await reports.loadMyUic();

    expect(reports.reportUnits.map((unit) => unit.label),
        ['Home Unit ($primary)', 'Attached Unit ($followed)']);
    expect(notifications, greaterThan(0));
    expect(ids(reports.unitReports), {'bravo'});
    expect(reports.myUic, primary);
    expect(repository.reports.single.uic, followed);
    expect(reports.unreadCount.value, 1);
  });

  test('unfollowing hides cached reports but retains them for automatic relay',
      () async {
    remote.throwOnFetch = StateError('disconnected');
    final reports = await start();
    await reports.storeIncomingReport(buildReport(
        entityId: 'held-peer',
        uic: followed,
        isOutgoing: false,
        isRead: false));
    await reports.syncRemoteLatticeReports();
    expect(ids(reports.unitReports), {'held-peer'});
    expect(reports.otherUnitReports, isEmpty);
    expect(reports.unreadCount.value, 1);
    expect(entity.published, isEmpty);

    await profiles.saveProfile(const Profile(uic: primary));
    await reports.loadMyUic();
    expect(reports.unitReports, isEmpty);
    expect(ids(reports.otherUnitReports), {'held-peer'});
    expect(ids(reports.externalReports), {'held-peer'});
    expect(ids(repository.reports), {'held-peer'});
    expect(reports.unreadCount.value, 0);

    remote.throwOnFetch = null;
    await reports.syncRemoteLatticeReports();
    expect(ids(entity.published), {'held-peer'});
    expect(entity.published.single.isOutgoing, isFalse);
    expect(mesh.broadcast, isEmpty);
    expect(reports.reportUnits.single.uic, primary);
  });

  test('normalization combines a vehicle history within its own followed UIC',
      () async {
    repository.reports.addAll([
      buildReport(
          entityId: 'home-old',
          bumperNumber: ' a-11 ',
          uic: ' wj8taa ',
          isOutgoing: false,
          timestamp: DateTime.utc(2026, 10, 5)),
      buildReport(
          entityId: 'home-new',
          bumperNumber: 'A-11',
          uic: primary,
          isOutgoing: false,
          timestamp: DateTime.utc(2026, 10, 6)),
      buildReport(
          entityId: 'attached',
          bumperNumber: 'a-11',
          uic: ' wab4c0 ',
          isOutgoing: false),
    ]);
    final reports = await start();
    final groups = reports.groupByVehicle(reports.unitReports);

    expect(groups.keys.toSet(), {
      (bumperNumber: 'A-11', uic: primary),
      (bumperNumber: 'A-11', uic: followed),
    });
    expect(
        groups[(bumperNumber: 'A-11', uic: primary)]!
            .map((report) => report.entityId),
        ['home-new', 'home-old']);
    expect(ids(groups[(bumperNumber: 'A-11', uic: followed)]!), {'attached'});
    expect(reports.otherUnitReports, isEmpty);
  });
}
