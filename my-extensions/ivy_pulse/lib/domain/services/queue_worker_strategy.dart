import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';

abstract class QueueWorkerStrategy {
  Future<void> start();
  Future<void> stop();

  Future<void> enqueue(QueuedSubmission submission);

  void trackPersisted(QueuedSubmission submission);

  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  });

  Future<int> pendingCount();
}
