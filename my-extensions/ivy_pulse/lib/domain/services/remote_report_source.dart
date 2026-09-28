import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

abstract class RemoteReportSource {
  Future<List<PmcsReport>> fetchRemotePmcsReports();

  Future<Set<String>> fetchKnownPmcsEntityIds();

  Future<Set<String>> fetchWithdrawnPmcsEntityIds();
}
