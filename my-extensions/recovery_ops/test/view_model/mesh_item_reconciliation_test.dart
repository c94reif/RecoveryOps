import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/data/services/mesh_item_report_store_strategy.dart';
import 'package:recovery_ops/data/services/sdk_mesh_broadcaster.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';
import 'package:recovery_ops/domain/usecases/navigation/publish_navigation_stopped.dart';
import '../support/fake_mesh_items.dart';
import '../support/sdk_delivery_fakes.dart';
import 'reports_view_model_test.dart' as support;

void main() {
  test('remote withdrawal removes all local copies after reconnect', () async {
    final items = FakeMeshItems();
    final store = MeshItemReportStoreStrategy(items: items);
    await store.deleteRecoveryEntity('r');
    final repo = support.FakeReportsRepository();
    for (final id in [1, 2]) {
      await repo.insertReport(RecoveryReport(
          id: id,
          entityId: 'r',
          fromCallsign: 'You',
          bumperNumber: 'A-11',
          issue: 'flat tire',
          recoveryType: 'Wrecker',
          latitude: 33,
          longitude: -84,
          timestamp: DateTime.utc(2026),
          isOutgoing: true));
    }
    final messaging = support.FakeMessagingService();
    final navigation = support.FakeNavigationViewModel();
    final vm = support.createVm(
        messaging: messaging,
        map: support.FakeMapService(),
        repo: repo,
        navVm: navigation,
        source: ItemSource(store));
    addTearDown(() {
      vm.dispose();
      messaging.dispose();
      navigation.dispose();
    });
    await Future<void>.delayed(Duration.zero);
    expect(vm.reports, hasLength(2));
    await vm.syncRemoteLatticeReports();
    expect(vm.reports, isEmpty);
    expect(await repo.getAllReports(), isEmpty);
    expect(await store.fetchRemoteRecoveryReports(), isEmpty);
  });

  test('failed withdrawal fetch preserves local reports', () async {
    final items = FakeMeshItems()..failList = true;
    final store = MeshItemReportStoreStrategy(items: items);
    final repo = support.FakeReportsRepository();
    await repo.insertReport(RecoveryReport(
        id: 1,
        entityId: 'r',
        fromCallsign: 'You',
        bumperNumber: 'A-11',
        issue: 'flat tire',
        recoveryType: 'Wrecker',
        latitude: 33,
        longitude: -84,
        timestamp: DateTime.utc(2026),
        isOutgoing: true));
    final messaging = support.FakeMessagingService();
    final navigation = support.FakeNavigationViewModel();
    final vm = support.createVm(
        messaging: messaging,
        map: support.FakeMapService(),
        repo: repo,
        navVm: navigation,
        source: ItemSource(store));
    addTearDown(() {
      vm.dispose();
      messaging.dispose();
      navigation.dispose();
    });
    await Future<void>.delayed(Duration.zero);
    await vm.syncRemoteLatticeReports();
    expect(vm.reports, hasLength(1));
    expect(await repo.getAllReports(), hasLength(1));
    expect(items.created, isEmpty);
  });

  test('stop use case sends peer notification and persists navigator stop',
      () async {
    final store = MeshItemReportStoreStrategy(items: FakeMeshItems());
    await store.publishNavigatorEntity(
        entityId: 'r',
        bumperNumber: 'A-11',
        issue: 'flat tire',
        typeName: 'Wrecker',
        vehiclePosition: const LatLng(33, -84),
        navigatorPosition: const LatLng(34, -85));
    final messaging = RecordingMessagingService();
    final stop = PublishNavigationStopped(
        SdkMeshBroadcaster(messaging: messaging),
        navigatorStore: store);
    await stop(entityId: 'r');
    expect(messaging.broadcasts.single, contains('navigation_stopped'));
    expect((await store.fetchNavigatorState('r'))!.stopped, isTrue);
  });
}

class ItemSource extends support.FakeRemoteReportSource
    implements ReportWithdrawalSource {
  ItemSource(this.store);
  final MeshItemReportStoreStrategy store;
  @override
  Future<Set<String>> fetchWithdrawnRecoveryEntityIds() =>
      store.fetchWithdrawnRecoveryEntityIds();
  @override
  Future<Set<String>> fetchKnownRecoveryEntityIds() =>
      store.fetchKnownRecoveryEntityIds();
  @override
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports() =>
      store.fetchRemoteRecoveryReports();
}
