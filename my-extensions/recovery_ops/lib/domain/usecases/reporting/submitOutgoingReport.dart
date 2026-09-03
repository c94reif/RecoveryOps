import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';

class SubmitOutgoingReport {
  final ReportsRepository repository;

  SubmitOutgoingReport(this.repository);

  Future<RecoveryReport> call({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
  }) async {
    final report = RecoveryReport(
      entityId: entityId,
      fromCallsign: 'You',
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now().toUtc(),
      isOutgoing: true,
      isRead: true,
    );
    await repository.insertReport(report);
    return report;
  }
}
