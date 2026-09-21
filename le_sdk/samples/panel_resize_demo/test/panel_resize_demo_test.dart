import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart';

import 'package:panel_resize_demo/panel_resize_demo_plugin.dart';

/// Pumps the demo inside a sized box so the panel-content layout is exercised.
/// Pass [ctx] to reuse a context whose storage was pre-seeded.
Future<StubExtensionContext> _pump(
  WidgetTester tester, {
  double width = 360,
  StubExtensionContext? ctx,
}) async {
  final context = ctx ?? StubExtensionContext();
  await tester.pumpWidget(MaterialApp(
    theme: LatticeTheme.dark(),
    home: Scaffold(
      body: SizedBox(width: width, child: PanelResizeDemoPlugin().build(context)),
    ),
  ));
  // Let the post-frame restore + getPanelSize round-trip settle.
  await tester.pumpAndSettle();
  return context;
}

void main() {
  testWidgets('renders the card, image, and control bar', (tester) async {
    await _pump(tester);

    expect(find.text('Panel Resize Demo'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byIcon(Icons.arrow_left), findsOneWidget);
    expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
  });

  testWidgets('starts at the smallest size (xsmall)', (tester) async {
    final ctx = await _pump(tester);
    expect(await ctx.ui.getPanelSize(), PanelSize.xsmall);
    expect(find.text('XSMALL'), findsOneWidget);
  });

  testWidgets('grow steps xsmall -> small -> medium -> large then stops',
      (tester) async {
    final ctx = await _pump(tester);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.small);
    expect(find.text('SMALL'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.medium);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.large);
    expect(find.text('LARGE'), findsOneWidget);

    final growButton = tester.widget<InkWell>(
      find.ancestor(of: find.byIcon(Icons.arrow_left), matching: find.byType(InkWell)),
    );
    expect(growButton.onTap, isNull);
  });

  testWidgets('shrink steps back down toward xsmall', (tester) async {
    final ctx = await _pump(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pumpAndSettle();
    }
    expect(await ctx.ui.getPanelSize(), PanelSize.large);

    await tester.tap(find.byIcon(Icons.arrow_right));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.medium);
  });

  testWidgets('reset returns to xsmall from any size', (tester) async {
    final ctx = await _pump(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pumpAndSettle();
    }
    expect(await ctx.ui.getPanelSize(), PanelSize.large);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.xsmall);
    expect(find.text('XSMALL'), findsOneWidget);
  });

  testWidgets('the note text survives a resize-triggered rebuild', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'recon at grid 1234');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();

    expect(find.text('recon at grid 1234'), findsOneWidget);
  });

  testWidgets('persists the chosen size to storage', (tester) async {
    final ctx = await _pump(tester);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pumpAndSettle();
    expect(await ctx.ui.getPanelSize(), PanelSize.medium);

    expect(await ctx.storage.read('panel_size'), 'medium');
  });

  testWidgets('restores the saved size on entry (sticky)', (tester) async {
    final ctx = StubExtensionContext();
    await ctx.storage.write('panel_size', 'large');
    // Host resets the shared size on every transition; plugin must restore from its own storage.
    await ctx.ui.setPanelSize(PanelSize.small);

    await _pump(tester, ctx: ctx);

    expect(await ctx.ui.getPanelSize(), PanelSize.large);
    expect(find.text('LARGE'), findsOneWidget);
  });
}
