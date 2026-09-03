import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';

abstract class RemoteReportSource {
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports();
  Future<Set<String>> fetchKnownRecoveryEntityIds();
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId);
  Future<List<LatLng>?> fetchEntityGeometry(String entityId);
}
