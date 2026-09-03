import 'dart:async';

import 'package:recovery_ops/domain/entities/queuedRequest.dart';
import 'package:recovery_ops/domain/services/queuePromptStrategy.dart';

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
