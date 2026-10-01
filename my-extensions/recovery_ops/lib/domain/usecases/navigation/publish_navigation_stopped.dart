import 'package:recovery_ops/domain/services/mesh_broadcaster_port.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';

class PublishNavigationStopped {
  final MeshBroadcasterPort meshPort;
  final NavigatorStateStore? navigatorStore;

  PublishNavigationStopped(this.meshPort, {this.navigatorStore});

  Future<void> call({required String entityId}) async {
    await Future.wait([
      meshPort.broadcastNavigationStopped(entityId),
      if (navigatorStore != null) navigatorStore!.stopNavigator(entityId),
    ]);
  }
}
