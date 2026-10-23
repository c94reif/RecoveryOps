import 'package:recovery_ops/domain/services/recovery_entity_port.dart';
import 'package:recovery_ops/domain/services/remote_report_source.dart';

abstract class ReportWithdrawalSource {
  Future<Set<String>> fetchWithdrawnRecoveryEntityIds();
}

abstract class NavigatorStateStore {
  Future<bool> stopNavigator(String entityId);
}

abstract class ReportStoreStrategy
    implements RecoveryEntityPort, RemoteReportSource, ReportWithdrawalSource {}
