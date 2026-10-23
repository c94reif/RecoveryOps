import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/data/services/delivery/entity_report_store_strategy.dart';
import 'package:circle_x/data/services/delivery/main_thread_queue_worker.dart';
import 'package:circle_x/data/services/delivery/mesh_item_report_store_strategy.dart';
import 'package:circle_x/data/services/delivery/sdk_mesh_broadcaster.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';

import '../support/fake_mesh_items.dart';
import '../support/fakes.dart';
import 'lattice_pmcs_adapter_test.dart' show FakeEntityService;

class HangingMeshItems extends FakeMeshItems {
  String? block;
  bool commitBeforeTimeout = false;
  final pendingCreate = Completer<sdk.MeshItem>();
  sdk.MeshDataTypePath? delayedType;
  Map<String, Object?>? delayedData;

  bool take(String operation) {
    if (block != operation) return false;
    block = null;
    return true;
  }

  @override
  Future<sdk.MeshDataType?> getDataType(sdk.MeshDataTypePath path) =>
      take('schema')
          ? Completer<sdk.MeshDataType?>().future
          : super.getDataType(path);

  @override
  Future<List<sdk.MeshItem>> listItems(sdk.MeshDataTypePath type,
          {Map<String, Object?>? filter}) =>
      take('list')
          ? Completer<List<sdk.MeshItem>>().future
          : super.listItems(type, filter: filter);

  @override
  Future<sdk.MeshItem> createItem(
      sdk.MeshDataTypePath type, Map<String, Object?> data,
      {Duration? ttl}) async {
    if (take('create')) {
      delayedType = type;
      delayedData = data;
      if (commitBeforeTimeout) await super.createItem(type, data, ttl: ttl);
      return pendingCreate.future;
    }
    return super.createItem(type, data, ttl: ttl);
  }

  @override
  Future<sdk.MeshItem> updateItem(
      sdk.MeshItemPath path, Map<String, Object?> data,
      {Duration? ttl}) async {
    if (take('update')) {
      if (commitBeforeTimeout) await super.updateItem(path, data, ttl: ttl);
      return Completer<sdk.MeshItem>().future;
    }
    return super.updateItem(path, data, ttl: ttl);
  }

  @override
  Future<sdk.MeshItem?> getItem(sdk.MeshItemPath path) =>
      take('verify') ? Completer<sdk.MeshItem?>().future : super.getItem(path);

  void completeDelayedCreate() {
    pendingCreate.complete(seed(delayedType!, delayedData!));
  }
}

class HangingMessaging extends sdk.StubMessagingService {
  bool hang = true;
  final payloads = <String>[];

  @override
  Future<sdk.DeliveryReport> broadcast(String payload) {
    payloads.add(payload);
    if (hang) {
      hang = false;
      return Completer<sdk.DeliveryReport>().future;
    }
    return Future.value(const sdk.DeliveryReport(results: [
      sdk.DeliveryResult(peerId: 'peer', success: true),
    ]));
  }
}

class HangingEntities extends FakeEntityService {
  String? block;

  bool take(String operation) {
    if (block != operation) return false;
    block = null;
    return true;
  }

  @override
  Future<String> upsertEntity(sdk.Entity entity) =>
      take('write') ? Completer<String>().future : super.upsertEntity(entity);

  @override
  Future<sdk.Entity?> getEntity(String entityId) => take('read')
      ? Completer<sdk.Entity?>().future
      : super.getEntity(entityId);

  @override
  Future<List<sdk.Entity>> getEntities() => take('list')
      ? Completer<List<sdk.Entity>>().future
      : Future.value(stored.values.toList());
}

void main() {
  const timeout = Duration(milliseconds: 20);

  for (final operation in ['schema', 'list', 'create', 'update', 'verify']) {
    test('hung mesh $operation releases the report lock for a later retry',
        () async {
      final items = HangingMeshItems();
      final store =
          MeshItemReportStoreStrategy(items: items, requestTimeout: timeout);
      if (operation == 'update') {
        expect(await store.publishPmcsReport(buildReport(bumperNumber: 'OLD')),
            isTrue);
      }
      items.block = operation;
      final report = buildReport(bumperNumber: 'NEW');

      expect(await store.publishPmcsReport(report), isFalse);
      expect(await store.publishPmcsReport(report), isTrue);
      expect((await store.fetchRemotePmcsReports()).single.bumperNumber, 'NEW');
    });
  }

  for (final operation in ['schema', 'list']) {
    test('hung mesh $operation read fails instead of treating store as empty',
        () async {
      final items = HangingMeshItems()..block = operation;
      final store =
          MeshItemReportStoreStrategy(items: items, requestTimeout: timeout);

      await expectLater(
          store.fetchKnownPmcsEntityIds(), throwsA(isA<TimeoutException>()));
      expect(await store.fetchKnownPmcsEntityIds(), isEmpty);
    });
  }

  for (final operation in ['create', 'update']) {
    test('retry discovers mesh $operation committed before its response hung',
        () async {
      final items = HangingMeshItems()..commitBeforeTimeout = true;
      final store =
          MeshItemReportStoreStrategy(items: items, requestTimeout: timeout);
      if (operation == 'update') {
        expect(await store.publishPmcsReport(buildReport(bumperNumber: 'OLD')),
            isTrue);
      }
      items.block = operation;
      final report = buildReport(bumperNumber: 'NEW');

      expect(await store.publishPmcsReport(report), isFalse);
      final writes = items.created.length + items.updated.length;
      expect(await store.publishPmcsReport(report), isTrue);
      expect(items.created.length + items.updated.length, writes);
      expect(items.records, hasLength(1));
    });
  }

  test('late mesh publication cannot supersede a subsequent withdrawal',
      () async {
    final items = HangingMeshItems()..block = 'create';
    final store =
        MeshItemReportStoreStrategy(items: items, requestTimeout: timeout);
    expect(await store.publishPmcsReport(buildReport()), isFalse);
    expect(await store.deletePmcsEntity('session-1'), isTrue);

    items.completeDelayedCreate();
    await Future<void>.delayed(Duration.zero);

    expect(await store.fetchWithdrawnPmcsEntityIds(), {'session-1'});
    expect(await store.fetchRemotePmcsReports(), isEmpty);
  });

  test('timed-out peer broadcast leaves a retryable queue and clears send lock',
      () async {
    final messaging = HangingMessaging();
    final queue = FakeQueuedSubmissionsRepository();
    final delivery = DeliveryCoordinator();
    final worker = MainThreadQueueWorker(
      repository: queue,
      entityPort: FakePmcsEntityPort(),
      meshPort:
          SdkMeshBroadcaster(messaging: messaging, requestTimeout: timeout),
      delivery: delivery,
    );
    addTearDown(() async {
      await worker.stop();
      await delivery.dispose();
    });
    await worker.enqueue(buildQueuedSubmission(transport: TransportKind.mesh));

    await worker.retryNow();
    expect(await queue.count(), 1);
    expect(delivery.status('session-1', TransportKind.mesh),
        DeliveryStatus.queued);
    await worker.retryNow();

    expect(await queue.count(), 0);
    expect(messaging.payloads, hasLength(2));
    expect(
        delivery.status('session-1', TransportKind.mesh), DeliveryStatus.sent);
  });

  for (final operation in ['write', 'read']) {
    test('hung legacy entity $operation fails and permits another publication',
        () async {
      final entities = HangingEntities()..block = operation;
      final store =
          EntityReportStoreStrategy(entities, requestTimeout: timeout);

      expect(await store.publishPmcsReport(buildReport()), isFalse);
      expect(await store.publishPmcsReport(buildReport()), isTrue);
      entities.block = operation;
      expect(await store.deletePmcsEntity('session-1'), isFalse);
      expect(await store.deletePmcsEntity('session-1'), isTrue);
    });
  }

  test('hung legacy reads fail without discarding the next reconciliation',
      () async {
    final entities = HangingEntities();
    final store = EntityReportStoreStrategy(entities, requestTimeout: timeout);
    expect(await store.publishPmcsReport(buildReport()), isTrue);
    for (final read in [
      store.fetchRemotePmcsReports,
      store.fetchKnownPmcsEntityIds,
      store.fetchWithdrawnPmcsEntityIds,
    ]) {
      entities.block = 'list';
      await expectLater(read(), throwsA(isA<TimeoutException>()));
    }

    expect((await store.fetchRemotePmcsReports()).single.entityId, 'session-1');
    expect(await store.fetchKnownPmcsEntityIds(), {'session-1'});
  });
}
