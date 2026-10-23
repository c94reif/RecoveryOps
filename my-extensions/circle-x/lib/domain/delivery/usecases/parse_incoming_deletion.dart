import 'package:circle_x/domain/delivery/entities/incoming_report_message.dart';
import 'package:circle_x/domain/reporting/services/report_codec.dart';

class ParseIncomingDeletion {
  final ReportCodec codec;

  const ParseIncomingDeletion(this.codec);

  String? call(IncomingReportMessage message) =>
      codec.decodeDeletion(message.payload);
}
