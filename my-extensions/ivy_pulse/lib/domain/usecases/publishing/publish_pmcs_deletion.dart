import 'package:ivy_pulse/domain/services/diagnostic_logger.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/repositories/reports_repo.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/services/transaction_runner.dart';

class PublishPmcsDeletion {
  final DiagnosticLogger logger;
  final PmcsEntityPort entityPort;
  final ReportCodec codec;
  final Clock clock;
  final MeshBroadcasterPort meshPort;
  final QueueWorkerStrategy queueWorker;
  final ReportsRepository repository;
  final DeliveryCoordinator delivery;
  final QueuedSubmissionsRepository queuedRepository;
  final TransactionRunner transaction;
  final _inFlight = <String, Future<PublishResult>>{};

  PublishPmcsDeletion({
    this.logger = const SilentDiagnosticLogger(),
    required this.entityPort,
    required this.codec,
    this.clock = const SystemClock(),
    required this.meshPort,
    required this.queueWorker,
    required this.repository,
    required this.delivery,
    required this.queuedRepository,
    required this.transaction,
  });

  Future<PublishResult> call(PmcsReport report) => _inFlight.putIfAbsent(
      report.entityId,
      () => _publish(report).whenComplete(() {
            _inFlight.remove(report.entityId);
          }));

  Future<PublishResult> _publish(PmcsReport report) async {
    final payload = codec.encodeDeletion(report.entityId);
    final parked = await transaction.run(() async {
      final rows = <QueuedSubmission>[];
      for (final transport in TransportKind.values) {
        rows.add(await queuedRepository.insert(QueuedSubmission(
          entityId: report.entityId,
          bumperNumber: report.bumperNumber,
          vehicleType: report.vehicleType.displayName,
          redXCount: report.tally.redX,
          faultCount: report.tally.total,
          latitude: report.latitude,
          longitude: report.longitude,
          payload: payload,
          transport: transport,
          createdAt: clock.nowUtc(),
        )));
      }
      await repository.withdrawReport(report.entityId);
      return rows;
    });
    delivery.suppressReport(report.entityId);
    for (final row in parked) {
      queueWorker.trackPersisted(row);
    }

    Future<bool> send(
        TransportKind transport, Future<bool> Function() action) async {
      var success = false;
      try {
        success = await delivery.send(report.entityId, transport, action,
            withdrawal: true, queuedOnFailure: true);
      } catch (error) {
        logger.log('[IvyPulse] Withdrawal failed: $error');
      }
      queueWorker.reportTransportOutcome(
          transport: transport, success: success);
      return success;
    }

    final results = await Future.wait([
      send(TransportKind.lattice,
          () => entityPort.deletePmcsEntity(report.entityId)),
      send(TransportKind.mesh,
          () => meshPort.broadcastPmcsDeletion(report.entityId)),
    ]);
    return PublishResult(latticeOk: results[0], meshOk: results[1]);
  }
}
