import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/inspection/fault_note_dialog.dart';

import '../../support/inspection_harness.dart';

class UnavailableSpeech extends FakeSpeechRecognition {
  @override
  Future<void> startListening(
      {required void Function(String) onResult}) async {}
}

class SpeechResultOnStop extends FakeSpeechRecognition {
  @override
  Future<void> stopListening() async {
    await super.stopListening();
    await deliver('Leak at the lower seam');
  }
}

void main() {
  late FakeSpeechRecognition speech;

  setUp(() => speech = FakeSpeechRecognition());

  Widget subject(Future<bool> Function(String) onSave) => MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FaultNoteDialog(
                  itemName: 'Brake fluid',
                  condition: 'Reservoir cracked',
                  initialNote: 'Old note',
                  onSave: onSave,
                  speech: speech,
                ),
              ),
              child: const Text('Edit description'),
            ),
          ),
        ),
      );

  testWidgets('dictation adds an editable draft and saves only on confirmation',
      (tester) async {
    String? saved;
    await tester.pumpWidget(subject((text) async {
      saved = text;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictate description'));
    await tester.pumpAndSettle();

    expect(find.text('Stop recording'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await speech.deliver('Leaking at the seam');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Old note Leaking at the seam');
    expect(saved, isNull);
    await tester.enterText(find.byType(TextField), 'Leaking at the lower seam');
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(saved, 'Leaking at the lower seam');
  });

  testWidgets(
      'dictation respects the limit without splitting visible characters',
      (tester) async {
    await tester.pumpWidget(subject((_) async => true));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Dictate description'));
    await tester.pumpAndSettle();
    final description = List.filled(155, '👩🏽‍🔧').join();
    await speech.deliver('${description}x');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        description);
    expect(find.textContaining('Description limited to 155'), findsOneWidget);
  });

  testWidgets('stopping recording puts the final transcript in the draft',
      (tester) async {
    speech = SpeechResultOnStop();
    String? saved;
    await tester.pumpWidget(subject((text) async {
      saved = text;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Dictate description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop recording'));
    await tester.pumpAndSettle();

    expect(speech.stopCalls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Leak at the lower seam');
    expect(saved, isNull);
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(saved, 'Leak at the lower seam');
  });

  testWidgets('cancelling stops dictation and discards late results',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(subject((_) async {
      saves++;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictate description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(speech.stopCalls, 1);
    await speech.deliver('Late transcription');
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Old note');
  });

  testWidgets(
      'unavailable speech leaves the draft editable with an explanation',
      (tester) async {
    speech = UnavailableSpeech();
    String? saved;
    await tester.pumpWidget(subject((text) async {
      saved = text;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictate description'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dictation unavailable'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.enterText(find.byType(TextField), 'Typed description');
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(saved, 'Typed description');
  });

  testWidgets('descriptions are optional and limited to 155 visible characters',
      (tester) async {
    String? saved;
    await tester.pumpWidget(subject((text) async {
      saved = text;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    final description = List.filled(155, '👩🏽‍🔧').join();
    await tester.enterText(find.byType(TextField), '${description}x');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        description);
    expect(find.text('155/155'), findsOneWidget);
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(saved, description);

    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(saved, '');
  });

  testWidgets('a failed save keeps the draft and can be retried',
      (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(subject((text) async {
      saved.add(text);
      return saved.length > 1;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leak at lower seam');
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your text is still here'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Leak at lower seam');
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();
    expect(find.byType(FaultNoteDialog), findsNothing);
    expect(saved, ['Leak at lower seam', 'Leak at lower seam']);
  });

  testWidgets('cancelling an edit leaves the stored note alone',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(subject((_) async {
      saves++;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved edit');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(find.byType(FaultNoteDialog), findsNothing);
  });

  testWidgets('the note remains editable with a keyboard on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(370, 660);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    String? saved;
    await tester.pumpWidget(subject((text) async {
      saved = text;
      return true;
    }));
    await tester.tap(find.text('Edit description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leak at lower seam');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save description'));
    await tester.pumpAndSettle();

    expect(saved, 'Leak at lower seam');
    expect(tester.takeException(), isNull);
  });
}
