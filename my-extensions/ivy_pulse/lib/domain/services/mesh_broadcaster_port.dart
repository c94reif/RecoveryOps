import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

abstract class MeshBroadcasterPort {
  Future<bool> broadcastPmcsReport(PmcsReport report);

  Future<bool> broadcastEncodedReport(String payload);

  Future<bool> broadcastPmcsDeletion(String entityId);
}
