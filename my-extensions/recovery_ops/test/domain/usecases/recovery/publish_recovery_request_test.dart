import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/queue_worker_strategy.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_request.dart';

class FakeRecoveryEntityPort implements RecoveryEntityPort {
  bool publishOk = true;
  int callCount = 0;
  String? lastTypeName;

  @override
  Future<bool> publishRecoveryEntity({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    callCount++;
    lastTypeName = typeName;
    return publishOk;
  }

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

class FakeMeshPort implements MeshBroadcasterPort {
  bool broadcastOk = true;
  int callCount = 0;

  @override
  Future<bool> broadcastRecoveryRequest({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    callCount++;
    return broadcastOk;
  }

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

class FakeQueueWorker implements QueueWorkerStrategy {
  final List<QueuedRequest> enqueued = [];
  final List<({TransportKind transport, bool success})> outcomes = [];

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  @override
  Future<void> enqueue(QueuedRequest request) async {
    enqueued.add(request);
  }

  @override
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  }) {
    outcomes.add((transport: transport, success: success));
  }
}

void main() {
  late FakeRecoveryEntityPort entityPort;
  late FakeMeshPort meshPort;
  late FakeQueueWorker queue;
  late PublishRecoveryRequest usecase;

  setUp(() {
    entityPort = FakeRecoveryEntityPort();
    meshPort = FakeMeshPort();
    queue = FakeQueueWorker();
    usecase = PublishRecoveryRequest(
      entityPort: entityPort,
      meshPort: meshPort,
      queueWorker: queue,
    );
  });

  test('returns latticeOk and meshOk when both legs succeed', () async {
    entityPort.publishOk = true;
    meshPort.broadcastOk = true;

    final result = await usecase(
      entityId: 'e-1',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );

    expect(result.latticeOk, isTrue);
    expect(result.meshOk, isTrue);
    expect(result.allSucceeded, isTrue);
  });

  test('does not enqueue when both legs succeed', () async {
    await usecase(
      entityId: 'e-1',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );
    expect(queue.enqueued, isEmpty);
  });

  test('reports outcome to queue worker for each transport', () async {
    await usecase(
      entityId: 'e-1',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );
    final transports = queue.outcomes.map((o) => o.transport).toSet();
    expect(transports, {TransportKind.lattice, TransportKind.mesh});
  });

  test('enqueues only the failed leg when lattice fails', () async {
    entityPort.publishOk = false;

    final result = await usecase(
      entityId: 'e-2',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.wrecker,
      position: const LatLng(33.0, -84.0),
    );

    expect(result.latticeOk, isFalse);
    expect(result.meshOk, isTrue);
    expect(queue.enqueued.length, 1);
    expect(queue.enqueued.first.transport, TransportKind.lattice);
  });

  test('enqueues only the failed leg when mesh fails', () async {
    meshPort.broadcastOk = false;

    final result = await usecase(
      entityId: 'e-3',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );

    expect(result.latticeOk, isTrue);
    expect(result.meshOk, isFalse);
    expect(queue.enqueued.length, 1);
    expect(queue.enqueued.first.transport, TransportKind.mesh);
  });

  test('enqueues both legs when both fail', () async {
    entityPort.publishOk = false;
    meshPort.broadcastOk = false;

    final result = await usecase(
      entityId: 'e-4',
      bumperNumber: 'HQ-42',
      issue: 'flat tire',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );

    expect(result.allFailed, isTrue);
    expect(queue.enqueued.length, 2);
    final transports = queue.enqueued.map((q) => q.transport).toSet();
    expect(transports, {TransportKind.lattice, TransportKind.mesh});
  });

  test('queued payload preserves request fields', () async {
    entityPort.publishOk = false;
    meshPort.broadcastOk = false;

    await usecase(
      entityId: 'e-5',
      bumperNumber: 'BR-07',
      issue: 'engine failure',
      type: RecoveryType.wrecker,
      position: const LatLng(34.0, -85.0),
    );

    final lattice =
        queue.enqueued.firstWhere((q) => q.transport == TransportKind.lattice);
    expect(lattice.entityId, 'e-5');
    expect(lattice.bumperNumber, 'BR-07');
    expect(lattice.issue, 'engine failure');
    expect(lattice.recoveryType, 'Wrecker');
    expect(lattice.latitude, 34.0);
    expect(lattice.longitude, -85.0);
  });

  test('maps RecoveryType.towBar to "Tow Bar" typeName', () async {
    await usecase(
      entityId: 'e-6',
      bumperNumber: 'HQ-1',
      issue: 'x',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );
    expect(entityPort.lastTypeName, 'Tow Bar');
  });

  test('maps RecoveryType.wrecker to "Wrecker" typeName', () async {
    await usecase(
      entityId: 'e-7',
      bumperNumber: 'HQ-1',
      issue: 'x',
      type: RecoveryType.wrecker,
      position: const LatLng(33.0, -84.0),
    );
    expect(entityPort.lastTypeName, 'Wrecker');
  });

  test('calls each port exactly once', () async {
    await usecase(
      entityId: 'e-8',
      bumperNumber: 'HQ-1',
      issue: 'x',
      type: RecoveryType.towBar,
      position: const LatLng(33.0, -84.0),
    );
    expect(entityPort.callCount, 1);
    expect(meshPort.callCount, 1);
  });
}
