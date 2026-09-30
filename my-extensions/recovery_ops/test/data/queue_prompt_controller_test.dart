import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/domain/services/queue_prompt_strategy.dart';
import 'package:recovery_ops/presentation/common/services/queue_prompt_controller.dart';

import '../support/queued_request_fixture.dart';

void main() {
  late QueuePromptController controller;
  late StreamIterator<QueuePromptRequest> prompts;

  setUp(() {
    controller = QueuePromptController.create();
    prompts = StreamIterator(controller.prompts);
  });

  tearDown(() async {
    await prompts.cancel();
    controller.dispose();
  });

  for (final send in [true, false]) {
    test('returns the operator decision: ${send ? 'send' : 'discard'}',
        () async {
      final request = queuedRequest(id: 1);
      final next = prompts.moveNext();
      final answer = controller.ask(request);
      expect(await next, isTrue);
      expect(prompts.current.request, same(request));
      prompts.current.respond(send);
      expect(await answer, send);
    });
  }

  test('a repeated response cannot change the first operator decision',
      () async {
    final next = prompts.moveNext();
    final answer = controller.ask(queuedRequest(id: 1));
    await next;
    prompts.current.respond(true);
    prompts.current.respond(false);
    expect(await answer, isTrue);
  });

  test('concurrent requests receive their own answers even out of order',
      () async {
    final firstEvent = prompts.moveNext();
    final first = controller.ask(queuedRequest(id: 1));
    await firstEvent;
    final firstPrompt = prompts.current;
    final secondEvent = prompts.moveNext();
    final second = controller.ask(queuedRequest(id: 2));
    await secondEvent;
    final secondPrompt = prompts.current;

    expect(firstPrompt.request.id, 1);
    expect(secondPrompt.request.id, 2);
    secondPrompt.respond(true);
    firstPrompt.respond(false);
    expect(await first, isFalse);
    expect(await second, isTrue);
  });
}
