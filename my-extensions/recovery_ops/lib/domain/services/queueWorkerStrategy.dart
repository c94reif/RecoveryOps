import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';

abstract class QueueWorkerStrategy {
  Future<void> start();
  Future<void> stop();

  Future<void> enqueue(QueuedRequest request);

  void reportTransportOutcome({
    required TransportKind transport,
    required bool success,
  });
}
