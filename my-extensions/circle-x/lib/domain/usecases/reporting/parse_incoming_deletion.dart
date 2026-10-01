import 'package:circle_x/domain/entities/incoming_report_message.dart';
import 'package:circle_x/domain/services/report_codec.dart';

class ParseIncomingDeletion {
  final ReportCodec codec;

  const ParseIncomingDeletion(this.codec);

  String? call(IncomingReportMessage message) =>
      codec.decodeDeletion(message.payload);
}
