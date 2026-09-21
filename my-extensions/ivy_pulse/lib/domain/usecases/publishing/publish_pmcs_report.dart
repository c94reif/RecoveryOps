import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ivy_pulse/domain/entities/publish_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_report.dart';
import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
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

  const PublishPmcsReport({
    required this.entityPort,
    required this.meshPort,
    required this.queueWorker,
    required this.codec,
    required this.clock,
  });

  Future<PublishResult> call(PmcsReport report) async {
    final payload = codec.encodeReport(report);

    Future<bool> latticeLeg() async {
      final ok = await entityPort.publishPmcsReport(report);
      await _onLegOutcome(
        transport: TransportKind.lattice,
        success: ok,
        report: report,
        payload: payload,
      );
      return ok;
    }

    Future<bool> meshLeg() async {
      final ok = await meshPort.broadcastPmcsReport(report);
      await _onLegOutcome(
        transport: TransportKind.mesh,
        success: ok,
        report: report,
        payload: payload,
      );
      return ok;
    }

    final results = await Future.wait([latticeLeg(), meshLeg()]);
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
