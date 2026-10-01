import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/domain/entities/incoming_report_message.dart';
import 'package:circle_x/domain/services/report_message_source.dart';

class SdkReportMessageSource implements ReportMessageSource {
  final sdk.MessagingService messaging;

  const SdkReportMessageSource(this.messaging);

  @override
  Stream<IncomingReportMessage> get messages =>
      messaging.onMessageReceived.map((message) => IncomingReportMessage(
            payload: message.payload,
            fromCallsign: message.fromCallsign,
          ));
}
