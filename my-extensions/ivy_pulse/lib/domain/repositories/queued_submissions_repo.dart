import 'package:ivy_pulse/domain/entities/queued_submission.dart';

abstract class QueuedSubmissionsRepository {
  Future<List<QueuedSubmission>> getAll();
  Future<QueuedSubmission> insert(QueuedSubmission submission);
  Future<void> deleteById(int id);
  Future<int> count();
}
