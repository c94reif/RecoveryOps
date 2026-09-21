import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';

/// Decodes a mesh message into a PMCS report from another crew.
/// Returns null when the payload is not one of ours.
class ParseIncomingReport {
  final ReportCodec codec;

  const ParseIncomingReport(this.codec);

  PmcsReport? call(sdk.IncomingMessage message) {
    final callsign =
        message.fromCallsign.isEmpty ? 'Mesh' : message.fromCallsign;
    return codec.decodeReport(message.payload, fromCallsign: callsign);
  }
}
