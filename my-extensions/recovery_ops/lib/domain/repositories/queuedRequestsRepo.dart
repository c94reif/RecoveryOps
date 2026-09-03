import 'package:recovery_ops/domain/entities/queuedRequest.dart';

abstract class QueuedRequestsRepository {
  Future<List<QueuedRequest>> getAll();
  Future<QueuedRequest> insert(QueuedRequest request);
  Future<void> deleteById(int id);
}
