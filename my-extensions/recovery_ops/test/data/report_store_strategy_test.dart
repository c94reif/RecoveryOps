import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/core/config/report_store_config.dart';
import 'package:recovery_ops/data/services/entity_report_store_strategy.dart';
import 'package:recovery_ops/data/services/mesh_item_report_store_strategy.dart';
import 'package:recovery_ops/data/services/report_store_factory.dart';
import 'package:recovery_ops/domain/services/report_store_backend.dart';
import '../support/fake_mesh_items.dart';

void main() {
  late FakeMeshItems items;
  late MeshItemReportStoreStrategy store;
  setUp(() {
    items = FakeMeshItems();
    store = MeshItemReportStoreStrategy(items: items);
  });

  Future<bool> publish() => store.publishRecoveryEntity(
      entityId: 'r',
      bumperNumber: 'A-11',
      issue: 'flat tire',
      typeName: 'Wrecker',
      position: const LatLng(33, -84));

  Future<bool> navigate() => store.publishNavigatorEntity(
      entityId: 'r',
      bumperNumber: 'A-11',
      issue: 'flat tire',
      typeName: 'Wrecker',
      vehiclePosition: const LatLng(33, -84),
      navigatorPosition: const LatLng(34, -85),
      routeGeometry: const [LatLng(34, -85), LatLng(33, -84)]);

  test('reports round trip using stable report IDs and server item paths',
      () async {
    expect(await publish(), isTrue);
    final report = (await store.fetchRemoteRecoveryReports()).single;
    expect(report.entityId, 'r');
    expect(report.bumperNumber, 'A-11');
    expect(report.issue, 'flat tire');
    expect(report.latitude, 33);
    expect(report.isOutgoing, isFalse);
    expect(items.records.values.single.path.id, isNot('r'));
    expect(await store.fetchKnownRecoveryEntityIds(), {'r'});
  });

  test('navigation and geometry persist and survive queued report retries',
      () async {
    expect(await navigate(), isTrue);
    expect(await publish(), isTrue);
    final nav = await store.fetchNavigatorState('r');
    expect(nav!.navigatorLatitude, 34);
    expect(nav.navigatorLongitude, -85);
    expect(nav.stopped, isFalse);
    expect(await store.fetchEntityGeometry('r'),
        const [LatLng(34, -85), LatLng(33, -84)]);
    expect(items.records, hasLength(1));
  });

  test('stopping navigation persists across a new strategy instance', () async {
    await navigate();
    expect(await store.stopNavigator('r'), isTrue);
    store = MeshItemReportStoreStrategy(items: items);
    expect((await store.fetchNavigatorState('r'))!.stopped, isTrue);
    expect(await store.fetchEntityGeometry('r'), isNull);
    expect((await store.fetchRemoteRecoveryReports()).single.navigatorLatitude,
        isNull);
    expect(await store.stopNavigator('missing'), isTrue);
    expect(items.records, hasLength(1));
  });

  test('withdrawal suppresses reports and navigation, including later retries',
      () async {
    await navigate();
    expect(await store.deleteRecoveryEntity('r'), isTrue);
    expect(await publish(), isTrue);
    expect(await store.fetchRemoteRecoveryReports(), isEmpty);
    expect(await store.fetchKnownRecoveryEntityIds(), {'r'});
    expect(await store.fetchWithdrawnRecoveryEntityIds(), {'r'});
    expect(await store.fetchNavigatorState('r'), isNull);
    expect(await store.fetchEntityGeometry('r'), isNull);
  });

  test('invalid report and route data do not hide good reports', () async {
    items.seed(ReportStoreConfig.itemType, {
      'reportId': 'bad',
      'report': {'entityId': 'bad'}
    });
    items.seed(ReportStoreConfig.itemType, {'reportId': 'other'});
    await publish();
    expect((await store.fetchRemoteRecoveryReports()).map((r) => r.entityId),
        ['r']);
    expect(await store.fetchNavigatorState('r'), isNull);
    expect(await store.fetchNavigatorState('bad'), isNull);
    expect(await store.fetchEntityGeometry('bad'), isNull);
  });

  test('write failures fail delivery while read failures propagate', () async {
    items.schemaRegistered = false;
    expect(await publish(), isFalse);
    items.schemaRegistered = true;
    items.failWrites = true;
    expect(await store.deleteRecoveryEntity('r'), isFalse);
    items.failList = true;
    await expectLater(store.fetchKnownRecoveryEntityIds(), throwsStateError);
    await expectLater(store.fetchRemoteRecoveryReports(), throwsStateError);
  });

  test('default and custom paths do not access entity APIs', () {
    final context = ItemsOnlyContext(items);
    addTearDown(context.close);
    expect(createReportStore(context), isA<MeshItemReportStoreStrategy>());
    const custom = sdk.MeshDataTypePath(
        namespace: 'unit',
        domain: 'logistics',
        dataType: 'recovery',
        version: 'v2');
    final selected = createReportStore(context, itemType: custom)
        as MeshItemReportStoreStrategy;
    expect(selected.collection.type, same(custom));
    expect(
        ReportStoreBackend.fromEnvironment(), ReportStoreBackend.meshItemStore);
    expect(ReportStoreBackend.parse('entities'), ReportStoreBackend.entities);
    expect(() => ReportStoreBackend.parse('typo'), throwsArgumentError);
  });

  test('legacy strategy retains entity publication and navigation', () async {
    final context = sdk.StubExtensionContext();
    addTearDown(context.close);
    final legacy =
        createReportStore(context, backend: ReportStoreBackend.entities);
    expect(legacy, isA<EntityReportStoreStrategy>());
    expect(
        await legacy.publishRecoveryEntity(
            entityId: 'r',
            bumperNumber: 'A-11',
            issue: 'flat tire',
            typeName: 'Wrecker',
            position: const LatLng(33, -84)),
        isTrue);
    expect((await legacy.fetchRemoteRecoveryReports()).single.entityId, 'r');
    expect(await legacy.fetchKnownRecoveryEntityIds(), contains('r'));
    expect(
        await legacy.publishNavigatorEntity(
            entityId: 'r',
            bumperNumber: 'A-11',
            issue: 'flat tire',
            typeName: 'Wrecker',
            vehiclePosition: const LatLng(33, -84),
            navigatorPosition: const LatLng(34, -85),
            routeGeometry: const [LatLng(34, -85), LatLng(33, -84)]),
        isTrue);
    expect((await legacy.fetchNavigatorState('r'))!.navigatorLatitude, 34);
    expect(await legacy.fetchEntityGeometry('r'), hasLength(2));
    expect(await legacy.deleteRecoveryEntity('r'), isTrue);
    expect(await legacy.fetchWithdrawnRecoveryEntityIds(), contains('r'));
  });
}

class ItemsOnlyContext extends sdk.StubExtensionContext {
  ItemsOnlyContext(FakeMeshItems items) : store = FakeItemStore(items);
  final FakeItemStore store;
  @override
  sdk.MeshItemStoreService get meshItemStore => store;
  @override
  sdk.EntityService get entities =>
      throw StateError('entity backend must not be used');
}

class FakeItemStore implements sdk.MeshItemStoreService {
  FakeItemStore(this.items);
  @override
  final sdk.MeshItemService items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
