import 'package:circle_x/domain/entities/pmcs_report.dart';

abstract class MeshBroadcasterPort {
  Future<bool> broadcastPmcsReport(PmcsReport report);

  Future<bool> broadcastEncodedReport(String payload);

  Future<bool> broadcastPmcsDeletion(String entityId);
}
