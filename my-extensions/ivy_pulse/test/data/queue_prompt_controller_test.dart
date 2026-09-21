import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/presentation/common/services/queue_prompt_controller.dart';

import '../support/fakes.dart';

/// Lets the broadcast stream deliver what was just added.
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late QueuePromptController controller;
  late List<QueuePromptRequest> seen;
  late StreamSubscription<QueuePromptRequest> subscription;

  setUp(() {
    controller = QueuePromptController.create();
    seen = [];
    subscription = controller.prompts.listen(seen.add);
  });

  tearDown(() async {
    await subscription.cancel();
    controller.dispose();
  });

  test('raises a prompt carrying the parked submission', () async {
    unawaited(
      controller.ask(buildQueuedSubmission(payload: 'encoded:parked')),
    );
    await pump();

    expect(seen.single.submission.payload, 'encoded:parked');
  });

  test('answers send back to the queue', () async {
    final answer = controller.ask(buildQueuedSubmission());
    await pump();

    seen.single.respond(true);

    expect(await answer, isTrue);
  });

  test('answers discard back to the queue', () async {
    final answer = controller.ask(buildQueuedSubmission());
    await pump();

    seen.single.respond(false);

    expect(await answer, isFalse);
  });

  test('a second answer is ignored rather than thrown', () async {
    final answer = controller.ask(buildQueuedSubmission());
    await pump();

    seen.single.respond(true);
    expect(() => seen.single.respond(false), returnsNormally);

    expect(await answer, isTrue);
  });

  test('two prompts in flight each get their own answer', () async {
    final latticeAnswer = controller.ask(
      buildQueuedSubmission(payload: 'encoded:lattice'),
    );
    final meshAnswer = controller.ask(
      buildQueuedSubmission(
        payload: 'encoded:mesh',
        transport: TransportKind.mesh,
      ),
    );
    await pump();

    expect(seen, hasLength(2));

    seen[1].respond(true);
    seen[0].respond(false);

    expect(await latticeAnswer, isFalse);
    expect(await meshAnswer, isTrue);
  });

  test('reaches every listener, so a route change cannot swallow a prompt',
      () async {
    final second = <QueuePromptRequest>[];
    final other = controller.prompts.listen(second.add);

    unawaited(controller.ask(buildQueuedSubmission()));
    await pump();

    expect(seen, hasLength(1));
    expect(second, hasLength(1));

    await other.cancel();
  });

  test('a prompt raised with nobody listening answers null, not never',
      () async {
    // `prompts` is a broadcast stream, so a prompt raised while no
    // QueuePromptHost is mounted would otherwise be dropped and `ask` would
    // never complete — leaving the worker's `draining` flag stuck true and
    // that transport wedged until the app restarts.
    await subscription.cancel();

    final answer = await controller
        .ask(buildQueuedSubmission())
        .timeout(const Duration(milliseconds: 200));

    expect(answer, isNull);
  });

  test('null means leave it parked, not discard it', () async {
    await subscription.cancel();

    // Distinguishing "nobody was asked" from "the operator said no" is the
    // whole point: false deletes the submission, null must not.
    expect(await controller.ask(buildQueuedSubmission()), isNot(false));
  });

  test('the shared instance is the one every caller gets', () {
    expect(
        QueuePromptController.instance, same(QueuePromptController.instance));
  });
}
