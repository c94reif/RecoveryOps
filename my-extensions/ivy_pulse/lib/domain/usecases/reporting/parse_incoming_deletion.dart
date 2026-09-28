import 'package:ivy_pulse/domain/entities/incoming_report_message.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';

class ParseIncomingDeletion {
  final ReportCodec codec;

  const ParseIncomingDeletion(this.codec);

  String? call(IncomingReportMessage message) =>
      codec.decodeDeletion(message.payload);
}
