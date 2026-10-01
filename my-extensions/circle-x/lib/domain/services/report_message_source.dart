import 'package:circle_x/domain/entities/incoming_report_message.dart';

abstract interface class ReportMessageSource {
  Stream<IncomingReportMessage> get messages;
}
