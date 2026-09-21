import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';

/// Wraps the app so the queue can raise a dialog from the data layer, which
/// has no [BuildContext] of its own.
///
/// Prompts are queued rather than stacked: both transports can come back at
/// once, and an operator holding a dipstick answers one question at a time.
class QueuePromptHost extends StatefulWidget {
  final QueuePromptStrategy promptStrategy;
  final Widget child;

  const QueuePromptHost({
    super.key,
    required this.promptStrategy,
    required this.child,
  });

  @override
  State<QueuePromptHost> createState() => QueuePromptHostState();
}

class QueuePromptHostState extends State<QueuePromptHost> {
  StreamSubscription<QueuePromptRequest>? subscription;
  bool dialogOpen = false;
  final List<QueuePromptRequest> backlog = [];

  @override
  void initState() {
    super.initState();
    subscription = widget.promptStrategy.prompts.listen(onPrompt);
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void onPrompt(QueuePromptRequest prompt) {
    backlog.add(prompt);
    showNext();
  }

  Future<void> showNext() async {
    if (dialogOpen || backlog.isEmpty) return;
    if (!mounted) return;

    dialogOpen = true;
    final prompt = backlog.removeAt(0);
    final submission = prompt.submission;

    final send = await showDialog<bool>(
      context: context,
      // Dismissing by tapping outside is too easy in gloves, and the queue is
      // waiting on an answer either way.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${submission.transport.displayName} reconnected',
        ),
        content: Text(
          'Send queued PMCS?\n\n'
          '${submission.summary}\n'
          '${submission.faultSummary}',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(88, minTouchTarget),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(88, minTouchTarget),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    prompt.respond(send ?? false);

    dialogOpen = false;
    if (mounted) showNext();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
