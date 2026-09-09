import 'dart:async';

import 'package:flutter/material.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';

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

    final send = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${prompt.request.transport.displayName} reconnected',
        ),
        content: Text(
          'Send queued report?\n\n'
          '${prompt.request.summary}\n'
          'Issue: ${prompt.request.issue}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
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
