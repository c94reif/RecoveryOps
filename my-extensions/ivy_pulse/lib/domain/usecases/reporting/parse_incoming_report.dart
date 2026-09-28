import 'package:ivy_pulse/domain/entities/incoming_report_message.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';

class ParseIncomingReport {
  final ReportCodec codec;

  const ParseIncomingReport(this.codec);

  PmcsReport? call(IncomingReportMessage message) {
    final callsign =
        message.fromCallsign.isEmpty ? 'Mesh' : message.fromCallsign;
    return codec.decodeReport(message.payload, fromCallsign: callsign);
  }
}
