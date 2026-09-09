import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/usecases/recovery/publish_recovery_deletion.dart';

class FakeEntityPort implements RecoveryEntityPort {
  bool deleteOk = true;
  int deleteCount = 0;
  String? lastDeletedId;

  @override
  Future<bool> deleteRecoveryEntity(String entityId) async {
    deleteCount++;
    lastDeletedId = entityId;
    return deleteOk;
  }

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
}

class FakeMeshPort implements MeshBroadcasterPort {
  bool broadcastOk = true;
  int broadcastCount = 0;
  String? lastBroadcastId;

  @override
  Future<bool> broadcastRecoveryDeletion(String entityId) async {
    broadcastCount++;
    lastBroadcastId = entityId;
    return broadcastOk;
  }

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
  Future<void> broadcastNavigatorLocation({
    required String entityId,
    required LatLng navigatorPosition,
    List<LatLng>? routeGeometry,
  }) async {}

  @override
  Future<void> broadcastNavigationStopped(String entityId) async {}
}

void main() {
  late FakeEntityPort entityPort;
  late FakeMeshPort meshPort;
  late PublishRecoveryDeletion usecase;

  setUp(() {
    entityPort = FakeEntityPort();
    meshPort = FakeMeshPort();
    usecase = PublishRecoveryDeletion(
      entityPort: entityPort,
      meshPort: meshPort,
    );
  });

  test('calls both ports with the same entity id', () async {
    await usecase(entityId: 'entity-7');
    expect(entityPort.lastDeletedId, 'entity-7');
    expect(meshPort.lastBroadcastId, 'entity-7');
    expect(entityPort.deleteCount, 1);
    expect(meshPort.broadcastCount, 1);
  });

  test('returns success when both legs succeed', () async {
    final outcome = await usecase(entityId: 'entity-1');
    expect(outcome.allSucceeded, isTrue);
  });

  test('returns lattice failure when entity port fails', () async {
    entityPort.deleteOk = false;
    final outcome = await usecase(entityId: 'entity-1');
    expect(outcome.latticeOk, isFalse);
    expect(outcome.meshOk, isTrue);
  });

  test('returns mesh failure when mesh port fails', () async {
    meshPort.broadcastOk = false;
    final outcome = await usecase(entityId: 'entity-1');
    expect(outcome.latticeOk, isTrue);
    expect(outcome.meshOk, isFalse);
  });

  test('returns allFailed when both legs fail', () async {
    entityPort.deleteOk = false;
    meshPort.broadcastOk = false;
    final outcome = await usecase(entityId: 'entity-1');
    expect(outcome.allFailed, isTrue);
  });
}
