import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';

/// A peer can receive the review before the operator's original transmission.
/// Restore the included PMCS snapshot only when that original is absent.
Future<List<PmcsReport>> storeReceivedReport(
  ReportsRepository repository,
  PmcsReport report,
) async {
  final review = report.maintainerReview;
  if (review == null) return [await repository.insertReport(report)];
  if (review.sourceReportId == report.entityId) {
    throw ArgumentError('A review must have its own report ID');
  }
  if ((await repository.getWithdrawnIds()).contains(review.sourceReportId)) {
    throw ReportWithdrawn(review.sourceReportId);
  }
  final known = await repository.getAllReports();
  var original = known
      .where((candidate) =>
          candidate.entityId == review.sourceReportId &&
          !candidate.isMaintainerReview)
      .firstOrNull;
  original ??= await repository.insertReport(PmcsReport(
    entityId: review.sourceReportId,
    fromCallsign: report.fromCallsign,
    bumperNumber: report.bumperNumber,
    vehicleType: report.vehicleType,
    operator: report.operator,
    uic: report.uic,
    phases: report.phases,
    faults: report.faults,
    signature: report.signature,
    latitude: report.latitude,
    longitude: report.longitude,
    timestamp: report.timestamp,
    isOutgoing: false,
    isRead: false,
  ));
  return [original, await repository.insertReport(report)];
}
