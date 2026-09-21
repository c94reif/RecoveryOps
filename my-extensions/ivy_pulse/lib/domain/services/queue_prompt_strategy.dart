import 'package:ivy_pulse/domain/entities/queued_submission.dart';

class QueuePromptRequest {
  final QueuedSubmission submission;
  final void Function(bool send) respond;

  const QueuePromptRequest({required this.submission, required this.respond});
}

/// Asks the operator whether to send a parked submission now that its
/// transport is back. Keeps the queue worker free of any UI dependency.
abstract class QueuePromptStrategy {
  Stream<QueuePromptRequest> get prompts;

  /// True to send, false to discard, and **null when nobody could be asked** —
  /// no UI was listening. Null must leave the submission parked: silently
  /// discarding a PMCS the operator already chose to submit loses their work,
  /// and silently sending one they were never asked about is not the contract
  /// this queue advertises.
  Future<bool?> ask(QueuedSubmission submission);
}
