import 'package:circle_x/domain/entities/incoming_report_message.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/report_codec.dart';

class ParseIncomingReport {
  final ReportCodec codec;

  const ParseIncomingReport(this.codec);

  PmcsReport? call(IncomingReportMessage message) {
    final callsign =
        message.fromCallsign.isEmpty ? 'Mesh' : message.fromCallsign;
    return codec.decodeReport(message.payload, fromCallsign: callsign);
  }
}
