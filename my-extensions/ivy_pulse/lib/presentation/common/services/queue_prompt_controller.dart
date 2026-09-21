import 'dart:async';

import 'package:ivy_pulse/domain/entities/queued_submission.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';

/// Bridges the queue worker to whatever widget is currently on screen.
///
/// A singleton and a broadcast stream because the worker outlives every route:
/// a transport can come back while the operator is deep in a walk-around, and
/// the prompt has to find them wherever they are.
class QueuePromptController implements QueuePromptStrategy {
  static final QueuePromptController instance = QueuePromptController.create();

  QueuePromptController.create();

  final StreamController<QueuePromptRequest> controller =
      StreamController<QueuePromptRequest>.broadcast();

  @override
  Stream<QueuePromptRequest> get prompts => controller.stream;

  @override
  Future<bool?> ask(QueuedSubmission submission) {
    // A broadcast stream drops anything added while nobody is subscribed, so
    // without this the completer would never finish and the worker would sit
    // draining that transport for the rest of the session. Answer "nobody
    // asked" instead and let the queue retry on its next probe.
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
