import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/id_generator.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_page.dart';
import 'package:circle_x/presentation/maintainer/review_completion_dialog.dart';
import 'package:circle_x/presentation/maintainer/review_completion_mark.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';
import '../../support/maintainer_harness.dart';

void main() {
  late MaintainerHarness h;
  setUp(() async {
    await getIt.reset();
    h = MaintainerHarness();
    getIt.registerSingleton<IdGenerator>(FakeIdGenerator());
    getIt.registerSingleton<CacScannerStrategy>(h.scanner);
    getIt.registerSingleton<SpeechRecognitionStrategy>(h.speech);
    getIt.registerSingleton<VerifyOperatorIdentity>(h.verify(h.scanner));
    getIt.registerSingleton<SubmitMaintainerReview>(h.submit);
    getIt.registerSingleton<PublishPmcsReport>(h.publish);
    getIt.registerSingleton<ReportsViewModel>(FakeReportsViewModel());
  });
  tearDown(() => getIt.reset());

  Widget subject({bool reducedMotion = false}) => MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
            body: MaintainerReviewPage(report: h.report, onExit: () {})),
      );

  final dialog = find.byType(ReviewCompletionDialog);
  Finder dialogText(String text) =>
      find.descendant(of: dialog, matching: find.text(text));

  Future<void> tap(WidgetTester tester, String text) async {
    final button = find.text(text).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('the final verified swipe celebrates before CAC submission',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Confirmed engine leak.');
    await tap(tester, 'Verified');
    expect(dialog, findsNothing);
    await tester.enterText(
        find.byType(TextFormField), 'Brake damage confirmed.');

    final swipe = find.byKey(const ValueKey('fault-swipe-area'));
    await tester.ensureVisible(swipe);
    await tester.pumpAndSettle();
    await tester.drag(swipe, const Offset(180, 0));
    await tester.pump(const Duration(milliseconds: 120));
    expect(dialog, findsNothing);
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(dialog, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    final progress = tester
        .widget<ReviewCompletionMark>(find.byType(ReviewCompletionMark))
        .progress;
    expect(progress, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(dialogText('All faults verified'), findsOneWidget);
    expect(dialogText('2 of 2 verified'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.repository.reports, hasLength(1));
    expect(h.queue.submissions, isEmpty);

    await tap(tester, 'Sign & submit');
    expect(dialog, findsNothing);
    expect(find.text('Sign the review batch'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Scan CAC & submit');
    final review = h.repository.reports.last.maintainerReview!;
    expect(review.faults.map((fault) => fault.verified), [true, true]);
    expect(review.faults.map((fault) => fault.description),
        ['Confirmed engine leak.', 'Brake damage confirmed.']);
    expect(review.signature.isVerified, isTrue);
  });

  testWidgets(
      'mixed decisions finish accurately and edits can reach all verified',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, 'Verified');
    await tester.enterText(find.byType(TextFormField), 'Recheck brake line.');
    await tap(tester, 'Not verified');
    expect(dialogText('All faults reviewed'), findsOneWidget);
    expect(dialogText('1 verified · 1 not verified'), findsOneWidget);
    expect(find.text('All faults verified'), findsNothing);

    await tap(tester, 'Keep editing');
    expect(find.text('Recheck brake line.'), findsOneWidget);
    expect(find.text('All faults reviewed'), findsOneWidget);
    await tap(tester, 'Verified');
    expect(dialogText('All faults verified'), findsOneWidget);
    await tap(tester, 'Keep editing');
    await tap(tester, 'Verified');
    expect(dialog, findsNothing);
    expect(find.text('All faults verified'), findsOneWidget);
    await tap(tester, 'Submit review');
    await tap(tester, 'Back to review');
    expect(dialog, findsNothing);
    expect(find.text('Recheck brake line.'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);
  });

  testWidgets(
      'completion and sign controls fit a narrow panel with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, 'Verified');
    await tap(tester, 'Not verified');
    await tap(tester, 'Sign & submit');
    expect(find.text('Scan CAC & submit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'completion respects reduced motion and large text in a narrow panel',
      (tester) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(subject(reducedMotion: true));
    await tester.pumpAndSettle();
    await tap(tester, 'Not verified');
    await tap(tester, 'Not verified');
    expect(dialogText('All faults reviewed'), findsOneWidget);
    expect(dialogText('0 verified · 2 not verified'), findsOneWidget);
    expect(
        tester
            .widget<ReviewCompletionMark>(find.byType(ReviewCompletionMark))
            .progress,
        1);
    expect(tester.takeException(), isNull);
    await tap(tester, 'Keep editing');
    expect(dialog, findsNothing);
    expect(find.text('All faults reviewed'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
