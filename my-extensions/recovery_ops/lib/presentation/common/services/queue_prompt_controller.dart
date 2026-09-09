import 'dart:async';

import 'package:recovery_ops/domain/entities/queued_request.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';

class QueuePromptController implements QueuePromptStrategy {
  static final QueuePromptController instance = QueuePromptController.create();

  QueuePromptController.create();

  final StreamController<QueuePromptRequest> controller =
      StreamController<QueuePromptRequest>.broadcast();

  @override
  Stream<QueuePromptRequest> get prompts => controller.stream;

  @override
  Future<bool> ask(QueuedRequest request) {
    final completer = Completer<bool>();
    controller.add(
      QueuePromptRequest(
        request: request,
        respond: (send) {
          if (!completer.isCompleted) completer.complete(send);
        },
      ),
    );
    return completer.future;
  }

  void dispose() {
    controller.close();
  }
}
