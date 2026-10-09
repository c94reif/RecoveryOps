import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/common/widgets/uic_text_field.dart';

void main() {
  testWidgets('pasting a spaced UIC keeps all six characters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: UicTextField(controller: controller))));

    await tester.enterText(find.byType(TextField), ' w ab 4 c0 ');
    await tester.pumpAndSettle();

    expect(controller.text, 'WAB4C0');
    expect(controller.selection.baseOffset, 6);
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('UIC must be exactly 6 characters'), findsNothing);

    await tester.enterText(find.byType(TextField), ' w ab 4 c00 ');
    await tester.pumpAndSettle();
    expect(controller.text, 'WAB4C00');
    expect(find.text('UIC must be exactly 6 characters'), findsOneWidget);
  });

  testWidgets('normalizing a UIC keeps the cursor at the edited character',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: UicTextField(controller: controller))));
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'w ab4c0',
      selection: TextSelection.collapsed(offset: 3),
    ));
    await tester.pump();

    expect(controller.text, 'WAB4C0');
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets('counts characters and shows short, long and invalid UIC errors',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: UicTextField(controller: controller))));
    expect(find.text('0/6'), findsOneWidget);
    expect(find.text('UIC is required'), findsNothing);
    await tester.enterText(find.byType(TextField), 'wab');
    await tester.pumpAndSettle();
    expect(find.text('3/6'), findsOneWidget);
    expect(find.text('UIC must be exactly 6 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wab4c00');
    await tester.pumpAndSettle();
    expect(controller.text, 'WAB4C00');
    expect(find.text('7/6'), findsOneWidget);
    expect(find.text('UIC must be exactly 6 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'WAB!C0');
    await tester.pumpAndSettle();
    expect(find.text('Use only letters A–Z and numbers 0–9'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  wab4c0  ');
    await tester.pumpAndSettle();
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('6 letters or numbers required'), findsOneWidget);
    expect(find.text('UIC must be exactly 6 characters'), findsNothing);
    controller.text = 'WAB4C000';
    await tester.pumpAndSettle();
    expect(find.text('8/6'), findsOneWidget);
    expect(find.text('UIC must be exactly 6 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('UIC is required'), findsOneWidget);
  });
}
