import 'package:circle_x/domain/services/diagnostic_logger.dart';
import 'package:latlong2/latlong.dart';

import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/publish_result.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:circle_x/domain/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';
import 'package:circle_x/domain/services/report_codec.dart';

class PublishPmcsReport {
  final DiagnosticLogger logger;
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueueWorkerStrategy queueWorker;
  final ReportCodec codec;
  final Clock clock;

  final DeliveryCoordinator delivery;
  final Map<String, Future<PublishResult>> inFlight = {};

  PublishPmcsReport({
    this.logger = const SilentDiagnosticLogger(),
    required this.entityPort,
    required this.meshPort,
    required this.queueWorker,
    required this.codec,
    required this.clock,
    DeliveryCoordinator? delivery,
  }) : delivery = delivery ?? DeliveryCoordinator();

  Future<PublishResult> call(PmcsReport report) => inFlight.putIfAbsent(
      report.entityId,
      () => publish(report).whenComplete(() {
            inFlight.remove(report.entityId);
          }));

  Future<PublishResult> publishPersisted(PmcsReport report) =>
      inFlight.putIfAbsent(
          report.entityId,
          () => publish(report, queueOnFailure: false).whenComplete(() {
                inFlight.remove(report.entityId);
              }));

  Future<PublishResult> publish(PmcsReport report,
      {bool queueOnFailure = true}) async {
    final payload = codec.encodeReport(report);

    Future<bool> sendViaTransport(
        TransportKind transport, Future<bool> Function() send) async {
      final status = delivery.status(report.entityId, transport);
      if (status == DeliveryStatus.sent) return true;
      if (status == DeliveryStatus.queued) return false;
      bool sentSuccessfully;
      try {
        sentSuccessfully =
            await delivery.send(report.entityId, transport, send);
      } catch (error) {
        logger.log('[CircleX] ${transport.displayName} send failed: $error');
        sentSuccessfully = false;
      }
      try {
        await _handleTransportOutcome(
            transport: transport,
            success: sentSuccessfully,
            report: report,
            payload: payload,
            queueOnFailure: queueOnFailure);
        if (!sentSuccessfully) {
          delivery.update(report.entityId, transport, DeliveryStatus.queued);
        }
      } catch (_) {
        delivery.update(report.entityId, transport, DeliveryStatus.failed);
        rethrow;
      }
      return sentSuccessfully;
    }

    final results = await Future.wait([
      sendViaTransport(
          TransportKind.lattice, () => entityPort.publishPmcsReport(report)),
      sendViaTransport(
          TransportKind.mesh, () => meshPort.broadcastPmcsReport(report)),
    ]);
    final outcome = PublishResult(latticeOk: results[0], meshOk: results[1]);
    logger.log('[CircleX] Publish ${report.entityId} — '
        'Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }

  Future<void> _handleTransportOutcome({
    required TransportKind transport,
    required bool success,
    required PmcsReport report,
    required String payload,
    required bool queueOnFailure,
  }) async {
    queueWorker.reportTransportOutcome(transport: transport, success: success);
    if (success || !queueOnFailure) return;

    final tally = report.tally;
    await queueWorker.enqueue(
      QueuedSubmission(
        entityId: report.entityId,
        bumperNumber: report.bumperNumber,
        vehicleType: report.vehicleType.displayName,
        redXCount: tally.redX,
        faultCount: tally.total,
        latitude: report.latitude,
        longitude: report.longitude,
        payload: payload,
        transport: transport,
        createdAt: clock.nowUtc(),
      ),
    );
  }

  LatLng positionOf(PmcsReport report) =>
      LatLng(report.latitude, report.longitude);
}
