import 'package:circle_x/domain/entities/pmcs_report.dart';

abstract class ReportCodec {
  String encodeReport(PmcsReport report);

  PmcsReport? decodeReport(String payload, {required String fromCallsign});

  String encodeDeletion(String entityId);

  String? decodeDeletion(String payload);
}
