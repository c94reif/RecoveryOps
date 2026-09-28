import 'dart:async';

import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';

class QueuePromptController implements QueuePromptStrategy {
  static final QueuePromptController instance = QueuePromptController.create();

  QueuePromptController.create();

  final StreamController<QueuePromptRequest> controller =
      StreamController<QueuePromptRequest>.broadcast();

  @override
  Stream<QueuePromptRequest> get prompts => controller.stream;

  @override
  Future<bool?> ask(QueuedSubmission submission) {
    if (!controller.hasListener) return Future<bool?>.value();

    final completer = Completer<bool?>();
    controller.add(
      QueuePromptRequest(
        submission: submission,
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
