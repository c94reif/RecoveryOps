import 'package:ivy_pulse/domain/entities/pmcs_report.dart';

/// Pushes PMCS results peer-to-peer over the tactical mesh, for when the
/// Lattice backend is unreachable but the maintainer's EUD is not.
abstract class MeshBroadcasterPort {
  /// Returns false when no peer acknowledged the broadcast.
  Future<bool> broadcastPmcsReport(PmcsReport report);

  /// Re-broadcast an already-encoded payload while draining the queue.
  Future<bool> broadcastEncodedReport(String payload);

  Future<bool> broadcastPmcsDeletion(String entityId);
}
