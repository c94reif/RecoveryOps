import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/entities/transport_kind.dart';

abstract class QueueWorkerStrategy {
  Future<void> start();
  Future<void> stop();

  Future<void> enqueue(QueuedRequest request);

  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  });
}
