import 'package:ivy_pulse/domain/entities/report_message_type.dart';

class AppConstants {
  const AppConstants._();

  static const String extensionId = 'ivy_pulse';
  static const String extensionName = 'Ivy Pulse';
  static const String extensionDescription =
      'Guided PMCS for tactical vehicles';

  static const String entityDataType = 'PMCS_REPORT';

  static const String meshReportType = ReportMessageType.report;
  static const String meshDeletionType = ReportMessageType.deletion;

  static const Duration entityTtl = Duration(days: 1);

  static const Duration locationTimeout = Duration(seconds: 5);

  static const Duration remoteSyncInterval = Duration(minutes: 5);

  static const Duration transportProbeInterval = Duration(seconds: 45);

  static const Duration cacCaptureTimeout = Duration(seconds: 120);
}
