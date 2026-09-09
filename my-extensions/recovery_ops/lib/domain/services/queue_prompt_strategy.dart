import 'package:recovery_ops/domain/entities/queued_request.dart';

class QueuePromptRequest {
  final QueuedRequest request;
  final void Function(bool send) respond;

  const QueuePromptRequest({required this.request, required this.respond});
}

abstract class QueuePromptStrategy {
  Stream<QueuePromptRequest> get prompts;

  Future<bool> ask(QueuedRequest request);
}
