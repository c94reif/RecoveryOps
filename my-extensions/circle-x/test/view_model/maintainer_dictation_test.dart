import 'package:flutter_test/flutter_test.dart';
import '../support/inspection_harness.dart' show FakeSpeechRecognition;
import '../support/maintainer_harness.dart';

class UnavailableSpeech extends FakeSpeechRecognition {
  @override
  Future<void> startListening(
      {required void Function(String) onResult}) async {}
}

class ResultOnStop extends FakeSpeechRecognition {
  @override
  Future<void> stopListening() async {
    await super.stopListening();
    await deliver('Leak confirmed.');
  }
}

void main() {
  test(
      'recording locks the current fault and signature until its result arrives',
      () async {
    final h = MaintainerHarness();
    final model = h.model();
    addTearDown(model.dispose);
    model.decide(true);
    model.decide(false);
    model.select(0);
    model.describe('Engine:');
    await model.toggleDictation();
    expect(model.busy, isTrue);
    model.select(1);
    model.decide(false);
    model.requestSignature();
    model.describe('Replacement');
    expect(model.signing, isFalse);
    expect(model.index, 0);
    expect(model.decisions, [true, false]);
    await h.speech.deliver(' leak at lower seam. ');
    expect(model.descriptions, ['Engine: leak at lower seam.', '']);
    expect(model.busy, isFalse);
    model.requestSignature();
    await model.toggleDictation();
    expect(h.speech.isListening, isFalse);
    expect(model.signing, isTrue);
  });

  test(
      'stop includes the final transcript and unavailable speech keeps typing available',
      () async {
    final h = MaintainerHarness();
    final speech = ResultOnStop();
    final model = h.model(withSpeech: speech);
    addTearDown(model.dispose);
    await model.toggleDictation();
    await model.toggleDictation();
    expect(speech.stopCalls, 1);
    expect(model.descriptions.first, 'Leak confirmed.');
    expect(model.isDictating, isFalse);

    final unavailable = h.model(withSpeech: UnavailableSpeech());
    addTearDown(unavailable.dispose);
    unavailable.describe('Existing note.');
    await unavailable.toggleDictation();
    expect(unavailable.dictationMessage, contains('Dictation unavailable'));
    expect(unavailable.isDictating, isFalse);
    unavailable.describe('Typed note.');
    expect(unavailable.descriptions.first, 'Typed note.');
  });

  test('late results cannot change another fault or a disposed draft',
      () async {
    final h = MaintainerHarness();
    final model = h.model();
    await model.toggleDictation();
    final stale = h.speech.pendingResult!;
    await model.toggleDictation();
    model.select(1);
    await model.toggleDictation();
    stale('Wrong fault');
    expect(model.descriptions, ['', '']);
    expect(model.isDictating, isTrue);
    model.dispose();
    await h.speech.deliver('Arrived after leaving');
    expect(model.descriptions, ['', '']);
    expect(h.speech.stopCalls, 2);
    expect(h.queue.submissions, isEmpty);
  });

  test(
      'dictated Unicode stays within the submission limit without splitting characters',
      () async {
    final h = MaintainerHarness();
    final model = h.model();
    addTearDown(model.dispose);
    final prefix = List.filled(1991, 'a').join();
    model.describe(prefix);
    await model.toggleDictation();
    await h.speech.deliver('👩🏽‍🔧 extra');
    expect(model.descriptions.first, '$prefix 👩🏽‍🔧 ');
    expect(model.descriptions.first.length, 2000);
    expect(model.dictationMessage, contains('2,000'));
    model.decide(true);
    model.decide(false);
    model.requestSignature();
    await model.scanAndSubmit();
    expect(model.saved, isNotNull);
  });
}
