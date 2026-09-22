import 'package:flutter/foundation.dart';
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

/// Sends a completed PMCS on both transports at once.
///
/// The legs are independent: Lattice can be down while the mesh is up and vice
/// versa, so each is awaited separately and each failure parks its own copy on
/// the queue. The operator is never blocked on the net.
class PublishPmcsReport {
  final PmcsEntityPort entityPort;
  final MeshBroadcasterPort meshPort;
  final QueueWorkerStrategy queueWorker;
  final ReportCodec codec;
  final Clock clock;

  final DeliveryCoordinator delivery;
  final Map<String, Future<PublishResult>> inFlight = {};

  PublishPmcsReport({
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

    Future<bool> leg(
        TransportKind transport, Future<bool> Function() send) async {
      final status = delivery.status(report.entityId, transport);
      if (status == DeliveryStatus.sent) return true;
      if (status == DeliveryStatus.queued) return false;
      bool ok;
      try {
        ok = await delivery.send(report.entityId, transport, send);
      } catch (error) {
        debugPrint('[IvyPulse] ${transport.displayName} send failed: $error');
        ok = false;
      }
      // Queue ownership belongs to this submission even if the network call
      // joined a repair already in progress. The whole publish is coalesced,
      // so repeated taps cannot enqueue the same failed leg twice.
      try {
        await _onLegOutcome(
            transport: transport,
            success: ok,
            report: report,
            payload: payload);
        if (!ok) {
          delivery.update(report.entityId, transport, DeliveryStatus.queued);
        }
      } catch (_) {
        delivery.update(report.entityId, transport, DeliveryStatus.failed);
        rethrow;
      }
      return ok;
    }

    final results = await Future.wait([
      leg(TransportKind.lattice, () => entityPort.publishPmcsReport(report)),
      leg(TransportKind.mesh, () => meshPort.broadcastPmcsReport(report)),
    ]);
    final outcome = PublishResult(latticeOk: results[0], meshOk: results[1]);
    debugPrint('[IvyPulse] Publish ${report.entityId} — '
        'Lattice: ${outcome.latticeOk} | Mesh: ${outcome.meshOk}');
    return outcome;
  }

  Future<void> _onLegOutcome({
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
