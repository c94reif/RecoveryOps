import 'package:circle_x/domain/entities/pmcs_report.dart';

abstract class RemoteReportSource {
  Future<List<PmcsReport>> fetchRemotePmcsReports();

  Future<Set<String>> fetchKnownPmcsEntityIds();

  Future<Set<String>> fetchWithdrawnPmcsEntityIds();
}
