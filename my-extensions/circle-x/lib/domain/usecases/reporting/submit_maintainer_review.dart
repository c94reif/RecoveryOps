import 'package:circle_x/domain/entities/cac_identity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/report_codec.dart';
import 'package:circle_x/domain/services/transaction_runner.dart';

/// Saves a signed batch and both delivery attempts in one local transaction.
/// Each batch has its own ID; the operator's report remains immutable.
class SubmitMaintainerReview {
  final ReportsRepository reports;
  final QueuedSubmissionsRepository queue;
  final QueueWorkerStrategy worker;
  final TransactionRunner transaction;
  final ReportCodec codec;
  final Clock clock;

  const SubmitMaintainerReview({
    required this.reports,
    required this.queue,
    required this.worker,
    required this.transaction,
    required this.codec,
    required this.clock,
  });

  Future<PmcsReport> call({
    required String reviewId,
    required String sourceReportId,
    required List<FaultReview> faults,
    required CacIdentity identity,
  }) async {
    if (reviewId.isEmpty ||
        reviewId == sourceReportId ||
        !RegExp(r'^\d{10}$').hasMatch(identity.edipi) ||
        (identity.daysUntilCardExpiry ?? 0) < 0) {
      throw ArgumentError('A valid CAC scan is required');
    }
    final (stored, queued) = await transaction.run(() async {
      if ((await reports.getWithdrawnIds()).contains(sourceReportId)) {
        throw ReportWithdrawn(sourceReportId);
      }
      final all = await reports.getAllReports();
      final original = all
          .where((report) =>
              report.entityId == sourceReportId && !report.isMaintainerReview)
          .firstOrNull;
      if (original == null) {
        throw StateError('The original PMCS is no longer available');
      }
      final keys =
          original.faults.map((fault) => (fault.phase, fault.itemId)).toSet();
      if (keys.isEmpty ||
          faults.length != keys.length ||
          faults.map((fault) => fault.key).toSet().length != keys.length ||
          faults.any((fault) =>
              !keys.contains(fault.key) || fault.description.length > 2000)) {
        throw ArgumentError('Review every fault before signing the batch');
      }
      final existing =
          all.where((report) => report.entityId == reviewId).firstOrNull;
      if (existing != null) {
        if (existing.maintainerReview?.sourceReportId != sourceReportId) {
          throw StateError('Review ID is already in use');
        }
        return (existing, <QueuedSubmission>[]);
      }
      final now = clock.nowUtc();
      final batch = MaintainerReview(
        sourceReportId: sourceReportId,
        faults: faults,
        signature: PmcsSignature.verified(identity: identity, signedAt: now),
      );
      final record = await reports.insertReport(PmcsReport(
        entityId: reviewId,
        fromCallsign: 'You',
        bumperNumber: original.bumperNumber,
        vehicleType: original.vehicleType,
        operator: original.operator,
        uic: original.uic,
        phases: original.phases,
        faults: original.faults,
        signature: original.signature,
        maintainerReview: batch,
        latitude: original.latitude,
        longitude: original.longitude,
        timestamp: original.timestamp,
        isOutgoing: true,
        isRead: true,
      ));
      final pending = <QueuedSubmission>[];
      for (final transport in TransportKind.values) {
        pending.add(await queue.insert(QueuedSubmission(
          entityId: record.entityId,
          bumperNumber: record.bumperNumber,
          vehicleType: record.vehicleType.displayName,
          redXCount: record.tally.redX,
          faultCount: record.tally.total,
          latitude: record.latitude,
          longitude: record.longitude,
          payload: codec.encodeReport(record),
          transport: transport,
          createdAt: now,
        )));
      }
      return (record, pending);
    });
    for (final submission in queued) {
      worker.trackPersisted(submission);
    }
    return stored;
  }
}
