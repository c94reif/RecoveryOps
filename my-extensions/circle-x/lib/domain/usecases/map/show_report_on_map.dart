import 'package:circle_x/domain/services/diagnostic_logger.dart';
import 'package:circle_x/domain/services/report_map_port.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';

class ShowReportOnMap {
  final ReportMapPort mapService;
  final DiagnosticLogger logger;

  const ShowReportOnMap(this.mapService,
      {this.logger = const SilentDiagnosticLogger()});

  Future<String?> call(PmcsReport report, {String? previousMarkerId}) async {
    try {
      if (previousMarkerId != null) {
        await mapService.removeMarker(previousMarkerId);
      }

      final markerId = await mapService.addVehicleMarker(
        latitude: report.latitude,
        longitude: report.longitude,
        label: '${report.bumperNumber} — ${report.statusLabel}',
        isDeadlined: report.isDeadlined,
      );

      await mapService.focusLocation(
        latitude: report.latitude,
        longitude: report.longitude,
      );
      return markerId;
    } catch (error) {
      logger.log('[CircleX] ShowReportOnMap error: $error');
      return null;
    }
  }

  Future<void> clear(String markerId) async {
    try {
      await mapService.removeMarker(markerId);
    } catch (error) {
      logger.log('[CircleX] ShowReportOnMap clear error: $error');
    }
  }
}
