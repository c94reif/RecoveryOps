import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';

class PublishNavigationStopped {
  final MeshBroadcasterPort meshPort;

  PublishNavigationStopped(this.meshPort);

  Future<void> call({required String entityId}) {
    return meshPort.broadcastNavigationStopped(entityId);
  }
}
