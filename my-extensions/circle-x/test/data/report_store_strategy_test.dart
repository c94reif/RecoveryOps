import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/data/services/entity_report_store_strategy.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/data/services/report_store_factory.dart';
import 'package:circle_x/domain/services/report_store_backend.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';

void main() {
  late FakeMeshItems items;
  late MeshItemReportStoreStrategy store;
  setUp(() {
    items = FakeMeshItems();
    store = MeshItemReportStoreStrategy(items: items);
  });

  test('round trips a full PMCS report without entity APIs', () async {
    final report = buildReport(
        faults: [buildFault(severity: FaultSeverity.redX, note: 'oil leak')]);
    expect(await store.publishPmcsReport(report), isTrue);
    final restored = (await store.fetchRemotePmcsReports()).single;
    expect(const PmcsReportCodec().reportBody(restored),
        const PmcsReportCodec().reportBody(report));
    expect(restored.entityId, report.entityId);
    expect(restored.entityId, isNot(items.records.values.single.path.id));
    expect(restored.isOutgoing, isFalse);
    expect(restored.isRead, isFalse);
    expect(items.records.values.single.path.type.domain, 'circle-x');
  });

  test('existing encoded outbox payload publishes unchanged', () async {
    final report = buildReport();
    expect(
        await store.publishEncodedReport(
            entityId: report.entityId,
            payload: const PmcsReportCodec().encodeReport(report),
            position: const LatLng(33, -84)),
        isTrue);
    expect(await store.fetchKnownPmcsEntityIds(), {report.entityId});
  });

  test('invalid or mismatched queued payload fails without a write', () async {
    for (final payload in [
      'invalid',
      const PmcsReportCodec().encodeReport(buildReport())
    ]) {
      expect(
          await store.publishEncodedReport(
              entityId: 'different',
              payload: payload,
              position: const LatLng(33, -84)),
          isFalse);
    }
    expect(items.created, isEmpty);
  });

  test('withdrawn IDs remain known and are excluded from remote reports',
      () async {
    await store.publishPmcsReport(buildReport());
    expect(await store.deletePmcsEntity('session-1'), isTrue);
    expect(await store.fetchRemotePmcsReports(), isEmpty);
    expect(await store.fetchKnownPmcsEntityIds(), {'session-1'});
    expect(await store.fetchWithdrawnPmcsEntityIds(), {'session-1'});
    expect(await store.publishPmcsReport(buildReport()), isTrue);
    expect(await store.fetchRemotePmcsReports(), isEmpty);
  });

  test('missing schema and write failures leave delivery unsuccessful',
      () async {
    items.schemaRegistered = false;
    expect(await store.publishPmcsReport(buildReport()), isFalse);
    items.schemaRegistered = true;
    items.failWrites = true;
    expect(await store.publishPmcsReport(buildReport()), isFalse);
    expect(await store.deletePmcsEntity('session-1'), isFalse);
  });

  test('failed reads propagate so reconciliation cannot assume an empty store',
      () async {
    items.failList = true;
    await expectLater(store.fetchKnownPmcsEntityIds(), throwsStateError);
    await expectLater(store.fetchRemotePmcsReports(), throwsStateError);
    await expectLater(store.fetchWithdrawnPmcsEntityIds(), throwsStateError);
  });

  test('malformed and mismatched reports do not hide valid records', () async {
    items.seed(ReportStoreConfig.itemType, {
      'reportId': 'bad',
      'report': {'entityId': 'other'}
    });
    items.seed(ReportStoreConfig.itemType, {'reportId': 'empty'});
    await store.publishPmcsReport(buildReport());
    expect((await store.fetchRemotePmcsReports()).map((r) => r.entityId),
        ['session-1']);
  });

  test('mesh items are the default and do not access the entity service', () {
    final context = ItemsOnlyContext(items);
    expect(createReportStore(context), isA<MeshItemReportStoreStrategy>());
    context.close();
    expect(
        ReportStoreBackend.fromEnvironment(), ReportStoreBackend.meshItemStore);
    expect(ReportStoreBackend.parse('entities'), ReportStoreBackend.entities);
    expect(() => ReportStoreBackend.parse('typo'), throwsArgumentError);
  });

  test(
      'entity strategy stays selectable and delegates read and write operations',
      () async {
    final context = sdk.StubExtensionContext();
    addTearDown(context.close);
    final legacy =
        createReportStore(context, backend: ReportStoreBackend.entities);
    expect(legacy, isA<EntityReportStoreStrategy>());
    final report = buildReport();
    expect(await legacy.publishPmcsReport(report), isTrue);
    expect((await legacy.fetchRemotePmcsReports()).single.entityId,
        report.entityId);
    expect(await legacy.fetchKnownPmcsEntityIds(), contains(report.entityId));
    expect(
        await legacy.publishEncodedReport(
            entityId: report.entityId,
            payload: const PmcsReportCodec().encodeReport(report),
            position: const LatLng(33, -84)),
        isTrue);
    expect(await legacy.deletePmcsEntity(report.entityId), isTrue);
    expect(
        await legacy.fetchWithdrawnPmcsEntityIds(), contains(report.entityId));
  });

  test('custom deployment path is passed through the factory', () {
    const custom = sdk.MeshDataTypePath(
        namespace: 'unit',
        domain: 'maintenance',
        dataType: 'report',
        version: 'v2');
    final context = ItemsOnlyContext(items);
    final selected = createReportStore(context, itemType: custom)
        as MeshItemReportStoreStrategy;
    expect(selected.collection.type, same(custom));
    context.close();
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
