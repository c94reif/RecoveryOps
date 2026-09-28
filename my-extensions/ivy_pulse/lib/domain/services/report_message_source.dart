import 'package:ivy_pulse/domain/entities/incoming_report_message.dart';

abstract interface class ReportMessageSource {
  Stream<IncomingReportMessage> get messages;
}
