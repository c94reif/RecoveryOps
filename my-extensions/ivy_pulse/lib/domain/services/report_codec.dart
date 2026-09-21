import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Wire format for a PMCS report, shared by the mesh payload and the Lattice
/// entity description so both sides decode the same bytes.
abstract class ReportCodec {
  String encodeReport(PmcsReport report);

  /// Returns null when [payload] is not one of ours or is malformed.
  PmcsReport? decodeReport(String payload, {required String fromCallsign});

  String encodeDeletion(String entityId);

  /// Returns the entity id being withdrawn, or null if not a deletion.
  String? decodeDeletion(String payload);
}
