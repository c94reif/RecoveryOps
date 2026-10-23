import 'package:circle_x/domain/delivery/entities/queued_submission.dart';
import 'package:circle_x/domain/delivery/entities/transport_kind.dart';

abstract class QueueWorkerStrategy {
  Future<void> start();
  Future<void> stop();

  Future<void> retryNow() async {}

  Future<bool> sendNow(QueuedSubmission submission);

  Future<void> enqueue(QueuedSubmission submission);

  void trackPersisted(QueuedSubmission submission);

  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  });

  Future<int> pendingCount();
}
