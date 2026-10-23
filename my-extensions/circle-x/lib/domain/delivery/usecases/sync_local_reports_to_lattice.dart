import 'package:circle_x/domain/shared/services/diagnostic_logger.dart';

import 'package:circle_x/domain/reporting/entities/pmcs_report.dart';
import 'package:circle_x/domain/delivery/entities/queued_submission.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';
import 'package:circle_x/domain/delivery/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/reporting/repositories/reports_repo.dart';
import 'package:circle_x/domain/shared/services/clock.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:circle_x/domain/delivery/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/delivery/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/delivery/services/remote_report_source.dart';
import 'package:circle_x/domain/reporting/services/report_codec.dart';

class SyncLocalReportsToLattice {
  final DiagnosticLogger logger;
  final RemoteReportSource source;
  final PmcsEntityPort entityPort;

  final DeliveryCoordinator delivery;
  final QueuedSubmissionsRepository? queuedRepository;
  final ReportsRepository? reportsRepository;
  final QueueWorkerStrategy? queueWorker;
  final ReportCodec? codec;
  final Clock clock;

  SyncLocalReportsToLattice(
    this.source,
    this.entityPort, {
    this.logger = const SilentDiagnosticLogger(),
    DeliveryCoordinator? delivery,
    this.queuedRepository,
    this.reportsRepository,
    this.queueWorker,
    this.codec,
    this.clock = const SystemClock(),
  }) : delivery = delivery ??
            DeliveryCoordinator(reportsRepository: reportsRepository);

  Future<int> call(List<PmcsReport> reports) async {
    final revision = delivery.revision;
    try {
      final candidates = {
        for (final report in reports)
          if (report.entityId.isNotEmpty) report.entityId: report,
      };
      final withdrawn = Set<String>.of(
          await reportsRepository?.getWithdrawnIds() ?? const {});
      if (candidates.isEmpty && withdrawn.isEmpty) return 0;

      final remoteWithdrawn = await source.fetchWithdrawnPmcsEntityIds();
      for (final entityId in remoteWithdrawn) {
        delivery.suppressReport(entityId);
        await reportsRepository?.withdrawReport(entityId);
      }
      final knownIds = await source.fetchKnownPmcsEntityIds();
      final parked = await queuedRepository?.getAll() ?? const [];
      final queuedIds = parked
          .where((submission) => submission.transport == TransportKind.lattice)
          .map((submission) => submission.entityId)
          .toSet();
      final queuedWithdrawals = parked
          .where((submission) =>
              submission.transport == TransportKind.lattice &&
              submission.isWithdrawal)
          .map((submission) => submission.entityId)
          .toSet();
      var republished = 0;
      for (final entityId in withdrawn.difference(remoteWithdrawn)) {
        delivery.suppressReport(entityId);
        if (queuedWithdrawals.contains(entityId) ||
            delivery.status(entityId, TransportKind.lattice,
                    withdrawal: true) ==
                DeliveryStatus.queued) {
          continue;
        }
        if (await _relay(entityId, candidates[entityId], withdrawal: true)) {
          republished++;
        }
      }
      withdrawn.addAll(remoteWithdrawn);
      for (final report in candidates.values) {
        final sourceId = report.maintainerReview?.sourceReportId;
        if (withdrawn.contains(report.entityId) ||
            await delivery.isWithdrawn(report.entityId) ||
            (sourceId != null &&
                (withdrawn.contains(sourceId) ||
                    await delivery.isWithdrawn(sourceId)))) {
          continue;
        }
        if (knownIds.contains(report.entityId) ||
            queuedIds.contains(report.entityId) ||
            delivery.status(report.entityId, TransportKind.lattice) ==
                DeliveryStatus.queued ||
            delivery.status(report.entityId, TransportKind.lattice) ==
                DeliveryStatus.discarded ||
            delivery.busyOrAttemptedSince(
                report.entityId, TransportKind.lattice, revision)) {
          continue;
        }
        final sentSuccessfully = await _relay(report.entityId, report);
        if (sentSuccessfully) republished++;
      }
      if (republished > 0) {
        logger.log('[CircleX] Relayed $republished stored record(s)');
      }
      return republished;
    } catch (error) {
      logger.log('[CircleX] SyncLocalReportsToLattice error: $error');
      return 0;
    }
  }

  Future<bool> _relay(String entityId, PmcsReport? report,
      {bool withdrawal = false}) async {
    var success = false;
    try {
      success = await delivery.send(
        entityId,
        TransportKind.lattice,
        () => withdrawal
            ? entityPort.deletePmcsEntity(entityId)
            : entityPort.publishPmcsReport(report!),
        withdrawal: withdrawal,
      );
    } catch (error) {
      logger.log('[CircleX] Relay $entityId failed: $error');
    }
    queueWorker?.reportTransportOutcome(
        transport: TransportKind.lattice, success: success);
    if (success || queueWorker == null || codec == null) return success;
    try {
      await queueWorker!.enqueue(QueuedSubmission(
        entityId: entityId,
        bumperNumber: report?.bumperNumber ?? entityId,
        vehicleType: report?.vehicleType.displayName ?? 'PMCS',
        redXCount: report?.tally.redX ?? 0,
        faultCount: report?.tally.total ?? 0,
        latitude: report?.latitude ?? 0,
        longitude: report?.longitude ?? 0,
        payload: withdrawal
            ? codec!.encodeDeletion(entityId)
            : codec!.encodeReport(report!),
        transport: TransportKind.lattice,
        createdAt: clock.nowUtc(),
      ));
      delivery.update(entityId, TransportKind.lattice, DeliveryStatus.queued,
          withdrawal: withdrawal);
    } catch (error) {
      logger.log('[CircleX] Could not queue relay $entityId: $error');
    }
    return false;
  }
}
