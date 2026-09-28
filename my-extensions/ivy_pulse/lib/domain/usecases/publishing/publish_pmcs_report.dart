import 'package:ivy_pulse/domain/services/diagnostic_logger.dart';
import 'package:latlong2/latlong.dart';

import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/domain/services/report_codec.dart';

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

  Future<PublishResult> publish(PmcsReport report) async {
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
        logger.log('[IvyPulse] ${transport.displayName} send failed: $error');
        sentSuccessfully = false;
      }
      try {
        await _handleTransportOutcome(
            transport: transport,
            success: sentSuccessfully,
            report: report,
            payload: payload);
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
    logger.log('[IvyPulse] Publish ${report.entityId} — '
        'Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }

  Future<void> _handleTransportOutcome({
    required TransportKind transport,
    required bool success,
    required PmcsReport report,
    required String payload,
  }) async {
    queueWorker.reportTransportOutcome(transport: transport, success: success);
    if (success) return;

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
