import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';

/// Withdraws a submitted PMCS from both transports.
class PublishPmcsDeletion {
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;

  const PublishPmcsDeletion({
    required this.entityPort,
    required this.meshPort,
  });

  Future<PublishResult> call({required String entityId}) async {
    final results = await Future.wait([
      entityPort.deletePmcsEntity(entityId),
      meshPort.broadcastPmcsDeletion(entityId),
    ]);
    final outcome = PublishResult(latticeOk: results[0], meshOk: results[1]);
    debugPrint('[IvyPulse] Deletion $entityId — '
        'Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }
}
