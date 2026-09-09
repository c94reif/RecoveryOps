import 'package:flutter/foundation.dart';
import 'package:recovery_ops/domain/entities/publish_result.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';

class PublishRecoveryDeletion {
  final RecoveryEntityPort entityPort;
  final MeshBroadcasterPort meshPort;

  PublishRecoveryDeletion({
    required this.entityPort,
    required this.meshPort,
  });

  Future<PublishResult> call({required String entityId}) async {
    final results = await Future.wait([
      entityPort.deleteRecoveryEntity(entityId),
      meshPort.broadcastRecoveryDeletion(entityId),
    ]);
    final outcome = PublishResult(latticeOk: results[0], meshOk: results[1]);
    debugPrint(
        '[RecoveryOps] Deletion — Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }
}
