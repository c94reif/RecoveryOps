import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/publish_result.dart';
import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';
import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/queue_worker_strategy.dart';
import 'package:recovery_ops/domain/services/recovery_entity_port.dart';

class PublishRecoveryRequest {
  final RecoveryEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueueWorkerStrategy queueWorker;

  PublishRecoveryRequest({
    required this.entityPort,
    required this.meshPort,
    required this.queueWorker,
  });

  Future<PublishResult> call({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required RecoveryType type,
    required LatLng position,
  }) async {
    final typeName = type == RecoveryType.towBar ? 'Tow Bar' : 'Wrecker';

    Future<bool> latticeLeg() async {
      final ok = await entityPort.publishRecoveryEntity(
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        typeName: typeName,
        position: position,
      );
      await _onLegOutcome(
        transport: TransportKind.lattice,
        success: ok,
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        typeName: typeName,
        position: position,
      );
      return ok;
    }

    Future<bool> meshLeg() async {
      final ok = await meshPort.broadcastRecoveryRequest(
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        typeName: typeName,
        position: position,
      );
      await _onLegOutcome(
        transport: TransportKind.mesh,
        success: ok,
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        typeName: typeName,
        position: position,
      );
      return ok;
    }

    final results = await Future.wait([latticeLeg(), meshLeg()]);
    final outcome = PublishResult(latticeOk: results[0], meshOk: results[1]);
    debugPrint(
        '[RecoveryOps] Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }

  Future<void> _onLegOutcome({
    required TransportKind transport,
    required bool success,
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String typeName,
    required LatLng position,
  }) async {
    queueWorker.reportTransportOutcome(transport: transport, success: success);
    if (success) return;

    await queueWorker.enqueue(
      QueuedRequest(
        entityId: entityId,
        bumperNumber: bumperNumber,
        issue: issue,
        recoveryType: typeName,
        latitude: position.latitude,
        longitude: position.longitude,
        transport: transport,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
