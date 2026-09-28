import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

import '../support/fakes.dart';
import '../support/inspection_harness.dart';

class ControlledResultsRepository extends FakeResultsRepository {
  bool failWrites = false;
  Completer<void>? writeGate;
  int writes = 0;

  @override
  Future<void> upsertResult(
      String sessionId, PmcsPhase phase, CheckResult result) async {
    writes++;
    await writeGate?.future;
    if (failWrites) throw StateError('storage unavailable');
    await super.upsertResult(sessionId, phase, result);
  }
}

class UnavailableSpeech extends FakeSpeechRecognition {
  @override
  Future<void> startListening(
      {required void Function(String) onResult}) async {}
}

void main() {
  late ControlledResultsRepository results;
  late InspectionHarness harness;
  late InspectionViewModel viewModel;

  setUp(() async {
    clearSnackBars();
    results = ControlledResultsRepository();
    harness = InspectionHarness(resultsRepository: results);
    viewModel = harness.viewModel;
    await harness.beginPhase(PmcsPhase.before);
  });

  tearDown(() {
    viewModel.dispose();
    clearSnackBars();
  });

  test(
      'a failed answer keeps progress and the previous answer available for retry',
      () async {
    await viewModel.answer(brakeFluid, 1);
    viewModel.expandItem(brakeFluid.id);
    results.failWrites = true;

    await viewModel.answer(brakeFluid, 3);

    expect(viewModel.isBusy, isFalse);
    expect(viewModel.answeredCount, 1);
    expect(viewModel.results[brakeFluid.id]?.faultIndex, 1);
    expect(viewModel.expandedItemId, brakeFluid.id);
    expect(SnackBarService.instance.queue.last.message,
        contains('Tap the condition again to retry'));

    results.failWrites = false;
    await viewModel.answer(brakeFluid, 3);
    expect(viewModel.results[brakeFluid.id]?.faultIndex, 3);
    expect(viewModel.expandedItemId, parkingBrake.id);
  });

  test('rapid taps cannot write twice or leave while an answer is being saved',
      () async {
    final gate = results.writeGate = Completer<void>();
    final firstSave = viewModel.answer(brakeFluid, 1);
    await viewModel.answer(brakeFluid, 3);
    viewModel.backToPhases();
    await viewModel.completeActivePhase();

    expect(results.writes, 1);
    expect(viewModel.isBusy, isTrue);
    expect(viewModel.stage, InspectionStage.inspecting);
    expect(viewModel.answeredCount, 0);
    gate.complete();
    await firstSave;

    expect(viewModel.isBusy, isFalse);
    expect(viewModel.results[brakeFluid.id]?.faultIndex, 1);
    expect(viewModel.answeredCount, 1);
  });

  test('editing and removing a note preserves the check being reviewed',
      () async {
    await viewModel.answer(brakeFluid, 3);
    viewModel.expandItem(brakeFluid.id);
    viewModel.consumePendingScroll();

    expect(await viewModel.saveNote(brakeFluid, '  Leaking at seam  '), isTrue);
    expect(viewModel.results[brakeFluid.id]?.note, 'Leaking at seam');
    expect(viewModel.expandedItemId, brakeFluid.id);
    expect(viewModel.consumePendingScroll(), isNull);

    expect(await viewModel.saveNote(brakeFluid, '   '), isTrue);
    expect(viewModel.results[brakeFluid.id]?.note, isNull);
    expect(
        (await results.getResults('session-1', PmcsPhase.before))[brakeFluid.id]
            ?.note,
        isNull);
    expect(viewModel.results[brakeFluid.id]?.faultIndex, 3);
  });

  test('a failed note save keeps the previous stored note', () async {
    await viewModel.answer(brakeFluid, 1);
    await viewModel.saveNote(brakeFluid, 'Original note');
    results.failWrites = true;

    expect(await viewModel.saveNote(brakeFluid, 'Replacement'), isFalse);
    expect(viewModel.results[brakeFluid.id]?.note, 'Original note');
    expect(viewModel.isBusy, isFalse);
  });

  test(
      'a late transcript cannot restore a note after marking the check serviceable',
      () async {
    await viewModel.answer(brakeFluid, 3);
    await viewModel.toggleNoteDictation(brakeFluid);
    final lateResult = harness.speech.pendingResult!;
    await viewModel.answer(brakeFluid, 0);
    lateResult('Old fault description');
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.results[brakeFluid.id]?.isServiceable, isTrue);
    expect(viewModel.results[brakeFluid.id]?.note, isNull);
    expect(viewModel.isListening, isFalse);
  });

  test(
      'a transcript from a previous phase visit cannot overwrite a new recording',
      () async {
    await viewModel.answer(brakeFluid, 3);
    await viewModel.toggleNoteDictation(brakeFluid);
    final lateResult = harness.speech.pendingResult!;
    viewModel.backToPhases();
    await viewModel.openPhase(PmcsPhase.before);
    await viewModel.toggleNoteDictation(brakeFluid);

    lateResult('Stale recording');
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.results[brakeFluid.id]?.note, isNull);
    expect(viewModel.isListening, isTrue);

    await harness.speech.deliver('Current recording');
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.results[brakeFluid.id]?.note, 'Current recording');
  });

  test('unavailable dictation clears recording and points to typing', () async {
    final unavailable =
        InspectionHarness(speechRecognition: UnavailableSpeech());
    await unavailable.beginPhase(PmcsPhase.before);
    await unavailable.viewModel.answer(brakeFluid, 1);
    await unavailable.viewModel.toggleNoteDictation(brakeFluid);

    expect(unavailable.viewModel.isListening, isFalse);
    expect(unavailable.viewModel.listeningItemId, isNull);
    expect(SnackBarService.instance.queue.last.message,
        contains('use Add description'));
    unavailable.viewModel.dispose();
  });
}
