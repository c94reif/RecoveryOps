import 'package:circle_x/domain/delivery/entities/incoming_report_message.dart';

abstract interface class ReportMessageSource {
  Stream<IncomingReportMessage> get messages;
}
