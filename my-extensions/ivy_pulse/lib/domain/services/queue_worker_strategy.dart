import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';

/// Owns the offline submission queue: which transports are down, what is
/// parked for each, and when to offer a parked submission for re-send.
abstract class QueueWorkerStrategy {
  Future<void> start();
  Future<void> stop();

  /// Park a submission that failed its transport.
  Future<void> enqueue(QueuedSubmission submission);

  /// Tell the queue whether a transport just succeeded or failed, so it knows
  /// when that leg has come back up.
  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  });

  /// Number of submissions currently parked, for the queue badge.
  Future<int> pendingCount();
}
