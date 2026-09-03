import 'package:recovery_ops/domain/services/meshBroadcasterPort.dart';

class PublishNavigationStopped {
  final MeshBroadcasterPort meshPort;

  PublishNavigationStopped(this.meshPort);

  Future<void> call({required String entityId}) {
    return meshPort.broadcastNavigationStopped(entityId);
  }
}
