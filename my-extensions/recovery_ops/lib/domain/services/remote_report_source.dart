import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/domain/entities/recovery_report.dart';
import 'package:recovery_ops/domain/usecases/navigation/parse_navigator_update.dart';

abstract class RemoteReportSource {
  Future<List<RecoveryReport>> fetchRemoteRecoveryReports();
  Future<Set<String>> fetchKnownRecoveryEntityIds();
  Future<NavigatorUpdate?> fetchNavigatorState(String entityId);
  Future<List<LatLng>?> fetchEntityGeometry(String entityId);
}
