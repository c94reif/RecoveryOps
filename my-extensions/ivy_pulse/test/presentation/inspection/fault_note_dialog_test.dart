import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/inspection/fault_note_dialog.dart';

void main() {
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
                ),
              ),
              child: const Text('Edit description'),
            ),
          ),
        ),
      );

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
