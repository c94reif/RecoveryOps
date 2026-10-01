import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/common/widgets/custom_snack_bar.dart';

void main() {
  final service = SnackBarService.instance;

  setUp(service.queue.clear);
  tearDown(service.queue.clear);

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: const Scaffold(
          body: CustomSnackBar(child: SizedBox.expand()),
        ),
      );

  testWidgets('shows messages queued before the host mounts', (tester) async {
    service.enqueue('Saved locally');
    await tester.pumpWidget(subject());

    expect(find.text('Saved locally'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved locally'), findsNothing);
  });

  testWidgets('a message arriving during dismissal gets its full display time',
      (tester) async {
    await tester.pumpWidget(subject());
    service.enqueue('First report saved');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    service.enqueue('Second report saved');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Second report saved'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Second report saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Second report saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Second report saved'), findsNothing);
  });

  testWidgets('manual dismissal cancels the old timer before the next message',
      (tester) async {
    await tester.pumpWidget(subject());
    service.enqueue('Saved');
    service.enqueue('Needs attention', isError: true, persistent: true);
    await tester.pump();

    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Needs attention'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Needs attention'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('disposing the host cancels its timers', (tester) async {
    await tester.pumpWidget(subject());
    service.enqueue('Saved');
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching notification services detaches listeners and timers',
      (tester) async {
    final first = SnackBarService()..enqueue('First service');
    final second = SnackBarService()..enqueue('Second service');
    Widget host(SnackBarService notifications) => MaterialApp(
          home: CustomSnackBar(
            service: notifications,
            child: const SizedBox.expand(),
          ),
        );
    await tester.pumpWidget(host(first));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(host(second));
    first.enqueue('Detached service');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Second service'), findsOneWidget);
    expect(find.text('Detached service'), findsNothing);
    expect(first.queue.single.message, 'Detached service');
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
    expect(tester.takeException(), isNull);
  });
}
