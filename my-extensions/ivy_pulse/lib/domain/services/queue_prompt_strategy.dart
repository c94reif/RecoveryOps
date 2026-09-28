import 'package:ivy_pulse/domain/entities/queued_submission.dart';

class QueuePromptRequest {
  final QueuedSubmission submission;
  final void Function(bool send) respond;

  const QueuePromptRequest({required this.submission, required this.respond});
}

abstract class QueuePromptStrategy {
  Stream<QueuePromptRequest> get prompts;

  Future<bool?> ask(QueuedSubmission submission);
}
