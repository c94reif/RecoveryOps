import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/dao/queue/queued_requests_dao.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/repositories/queued_requests_repo_impl.dart';
import 'package:recovery_ops/data/services/isolate_queue_worker.dart';
import 'package:recovery_ops/data/services/mesh_item_report_store_strategy.dart';
import 'package:recovery_ops/data/services/sdk_mesh_broadcaster.dart';
import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_request.dart';
import '../support/fake_mesh_items.dart';
import '../support/sdk_delivery_fakes.dart';

void main() {
  test(
      'stored requests resume to mesh items and peers through the existing isolate outbox',
      () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    final queue = QueuedRequestsRepoImpl(QueuedRequestsDao(db));
    final items = FakeMeshItems()..failWrites = true;
    final messaging = RecordingMessagingService()..results = [];
    final peers = SdkMeshBroadcaster(messaging: messaging);
    final store = MeshItemReportStoreStrategy(items: items);
    var worker = IsolateQueueWorker(
        repository: queue,
        entityPort: store,
        meshPort: peers,
        promptStrategy: ApproveRetry());
    addTearDown(() async {
      await worker.stop();
      await Future<void>.delayed(Duration.zero);
      await db.close();
    });
    final publish = PublishRecoveryRequest(
        entityPort: store, meshPort: peers, queueWorker: worker);
    final result = await publish(
        entityId: 'r',
        bumperNumber: 'A-11',
        issue: 'flat tire',
        type: RecoveryType.wrecker,
        position: const LatLng(33, -84));
    expect(result.allFailed, isTrue);
    expect(await queue.getAll(), hasLength(2));
    await worker.stop();

    items.failWrites = false;
    messaging.results = [
      const sdk.DeliveryResult(peerId: 'peer', success: true)
    ];
    worker = IsolateQueueWorker(
        repository: queue,
        entityPort: MeshItemReportStoreStrategy(items: items),
        meshPort: peers,
        promptStrategy: ApproveRetry());
    await worker.start();
    final drained = db
        .select(db.queuedRequests)
        .watch()
        .firstWhere((rows) => rows.isEmpty)
        .timeout(const Duration(seconds: 5));
    for (final transport in TransportKind.values) {
      worker.reportTransportOutcome(transport: transport, success: true);
    }
    await drained;
    expect(await queue.getAll(), isEmpty);
    final remote = (await store.fetchRemoteRecoveryReports()).single;
    expect(remote.entityId, 'r');
    expect(remote.issue, 'flat tire');
    expect((jsonDecode(messaging.broadcasts.last) as Map)['entityId'], 'r');
  });
}

class ApproveRetry implements QueuePromptStrategy {
  @override
  Stream<QueuePromptRequest> get prompts => const Stream.empty();
  @override
  Future<bool> ask(QueuedRequest request) async => true;
}
