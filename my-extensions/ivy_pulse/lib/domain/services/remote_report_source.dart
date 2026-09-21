import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Reads PMCS reports other crews published to Lattice.
abstract class RemoteReportSource {
  Future<List<PmcsReport>> fetchRemotePmcsReports();

  /// Entity ids already present on the host, so locally-stored reports that
  /// never made it up can be re-published without creating duplicates.
  Future<Set<String>> fetchKnownPmcsEntityIds();
}
