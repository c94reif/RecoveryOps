import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/id_generator.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_page.dart';
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

  Widget subject() => MaterialApp(
      theme: appTheme,
      home: Scaffold(
          body: MaintainerReviewPage(report: h.report, onExit: () {})));

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    final button = find.text(text).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byTooltip('Search faults'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('fault-search-input')), query);
    await tester.pumpAndSettle();
  }

  Future<void> selectResult(WidgetTester tester, int index) async {
    final result = find.byKey(ValueKey(('fault-search-result', index)));
    await tester.ensureVisible(result);
    await tester.pumpAndSettle();
    await tester.tap(result);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'dictated text is editable, follows its fault, and is CAC-signed with the batch',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Inspected engine.');
    await tap(tester, 'Dictate description');
    expect(find.text('Stop recording'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.search))
            .onPressed,
        isNull);
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse);
    final next =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Next'));
    expect(next.onPressed, isNull);
    await h.speech.deliver('Leak at lower seam.');
    await tester.pumpAndSettle();
    expect(find.text('Inspected engine. Leak at lower seam.'), findsOneWidget);
    expect(h.repository.reports, hasLength(1));
    await tester.enterText(
        find.byType(TextFormField), 'Leak confirmed at lower seam.');
    await tap(tester, 'Verified');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
    await tap(tester, 'Dictate description');
    await h.speech.deliver('Brake line is intact.');
    await tester.pumpAndSettle();
    await tap(tester, 'Not verified');
    await tap(tester, 'Keep editing');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(find.text('Brake line is intact.'), findsOneWidget);
    await tap(tester, 'Previous');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Leak confirmed at lower seam.');
    await tester.enterText(
        find.byType(TextFormField), 'Leak confirmed at lower seal.');
    await tap(tester, 'Submit review');
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Scan CAC & submit');
    final review = h.repository.reports.last.maintainerReview!;
    expect(review.faults.map((f) => f.description),
        ['Leak confirmed at lower seal.', 'Brake line is intact.']);
    expect(review.faults.map((f) => f.verified), [true, false]);
    expect(h.queue.submissions, hasLength(2));
    expect(h.peers.broadcast, hasLength(1));
  });

  testWidgets(
      'swipes retain individual notes and Submit asks for CAC before sending',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'No leak reproduced');
    final swipe = find.byKey(const ValueKey('fault-swipe-area'));
    await tester.ensureVisible(swipe);
    await tester.drag(swipe, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField), 'Brake damage confirmed');
    await tester.ensureVisible(swipe);
    await tester.drag(swipe, const Offset(180, 0));
    await tester.pumpAndSettle();
    await tap(tester, 'Keep editing');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(swipe, findsOneWidget);
    expect(find.text('Brake damage confirmed'), findsOneWidget);
    await tap(tester, 'Submit review');
    expect(find.text('Sign the review batch'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Scan CAC & submit');
    final review = h.repository.reports
        .singleWhere((r) => r.isMaintainerReview)
        .maintainerReview!;
    expect(review.faults.map((f) => f.verified), [false, true]);
    expect(review.faults.map((f) => f.description),
        ['No leak reproduced', 'Brake damage confirmed']);
    expect(review.signature.isVerified, isTrue);
    expect(h.peers.broadcast, hasLength(1));
    expect(find.textContaining('CAC signed by'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
      'buttons work without swiping and rejected CAC has no unsigned bypass',
      (tester) async {
    h.scanner.willFail(CacRejection.noCamera);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, 'Verified');
    await tap(tester, 'Not verified');
    await tap(tester, 'Sign & submit');
    await tap(tester, 'Scan CAC & submit');
    expect(find.textContaining('A CAC scan is required'), findsOneWidget);
    expect(h.repository.reports, hasLength(1));
    expect(h.queue.submissions, isEmpty);
    expect(find.text('Submit unverified'), findsNothing);
    await tap(tester, 'Back to review');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(find.textContaining('2 of 2 reviewed.'), findsOneWidget);
  });

  testWidgets(
      'an animated decision finishes before navigation or CAC submission',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, 'Verified');
    await tap(tester, 'Verified');
    await tap(tester, 'Keep editing');
    await tap(tester, 'Previous');
    final button = find.widgetWithText(OutlinedButton, 'Not verified');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 60));
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.search))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Submit review'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Dictate description'))
            .onPressed,
        isNull);
    await tester.pumpAndSettle();
    await tap(tester, 'Submit review');
    expect(find.text('1 verified · 1 not verified'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
  });

  testWidgets(
      'completed faults stay in the deck and can be revisited individually',
      (tester) async {
    tester.view.physicalSize = const Size(360, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    final firstNote = List.filled(
            5, 'Engine inspected and the leak was confirmed at the lower seam.')
        .join(' ');
    await tester.enterText(find.byType(TextFormField), firstNote);
    await tap(tester, 'Verified');
    await tester.enterText(
        find.byType(TextFormField), 'Brake line intact after pressure check.');
    await tap(tester, 'Not verified');
    await tap(tester, 'Keep editing');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('fault-swipe-area')), findsOneWidget);
    expect(find.text(firstNote), findsNothing);
    await tap(tester, 'Previous');
    expect(find.text('Fault 1 of 2'), findsOneWidget);
    expect(find.text(firstNote), findsOneWidget);
    expect(find.text('Brake line intact after pressure check.'), findsNothing);
    await tap(tester, 'Next');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(
        find.text('Brake line intact after pressure check.'), findsOneWidget);
    expect(find.textContaining('2 of 2 reviewed.'), findsOneWidget);
    // Swiping reviewed cards keeps advancing through the deck.
    await tap(tester, 'Not verified');
    expect(find.text('Fault 1 of 2'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'swiping to a shorter card preserves the scroll position through the final decision',
      (tester) async {
    tester.view.physicalSize = const Size(360, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField),
        List.filled(8, 'Long engine inspection note.').join(' '));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find
        .descendant(
          of: find.byKey(const ValueKey('review-faults')),
          matching: find.byType(Scrollable),
        )
        .first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final swipe = find.byKey(const ValueKey('fault-swipe-area'));
    await tester.ensureVisible(swipe);
    await tester.pumpAndSettle();
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(100));
    await tester.drag(swipe, const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(scroll.position.pixels, closeTo(offset, .1));
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Submit review'))
            .onPressed,
        isNull);
    await tester.drag(swipe, const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tap(tester, 'Keep editing');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(scroll.position.pixels, closeTo(offset, .1));
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Submit review'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search jumps to the original fault and edits completed cards without losing the batch',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Leak at lower seam.');
    await search(tester, '  bRaKe   lines  ');
    expect(find.text('1 of 2 faults'), findsOneWidget);
    expect(
        find.byKey(const ValueKey(('fault-search-result', 0))), findsNothing);
    await selectResult(tester, 1);
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
    await tester.enterText(
        find.byType(TextFormField), 'Hydraulic hose intact.');
    await tap(tester, 'Not verified');
    expect(find.text('Fault 1 of 2'), findsOneWidget);
    expect(find.text('Leak at lower seam.'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Submit review'))
            .onPressed,
        isNull);
    await tap(tester, 'Verified');
    await tap(tester, 'Keep editing');
    expect(find.text('Fault 1 of 2'), findsOneWidget);
    await search(tester, 'hydraulic');
    expect(find.text('Not verified · draft'), findsOneWidget);
    await selectResult(tester, 1);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Hydraulic hose intact.');
    await tester.enterText(
        find.byType(TextFormField), 'No leak under pressure.');
    await search(tester, 'pressure');
    expect(find.text('1 of 2 faults'), findsOneWidget);
    await tester.tap(find.byTooltip('Close fault search'));
    await tester.pumpAndSettle();
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    await tap(tester, 'Submit review');
    expect(find.byTooltip('Search faults'), findsNothing);
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Scan CAC & submit');
    final review = h.repository.reports.last.maintainerReview!;
    expect(review.faults.map((fault) => fault.verified), [true, false]);
    expect(review.faults.map((fault) => fault.description),
        ['Leak at lower seam.', 'No leak under pressure.']);
    expect(h.queue.submissions, hasLength(2));
    expect(h.peers.broadcast, hasLength(1));
  });

  testWidgets(
      'no matches can be cleared and cancelling search preserves the current draft',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Unsent engine note.');
    await search(tester, 'missing-fault');
    expect(find.text('No faults match your search.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear fault search'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 faults'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('fault-search-input')), 'operator note');
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 faults'), findsOneWidget);
    expect(
        find.byKey(const ValueKey(('fault-search-result', 0))), findsOneWidget);
    await tester.tap(find.byTooltip('Close fault search'));
    await tester.pumpAndSettle();
    expect(find.text('Fault 1 of 2'), findsOneWidget);
    expect(find.text('Unsent engine note.'), findsOneWidget);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);
  });

  testWidgets(
      'fault search fits a narrow screen with a keyboard and larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await search(tester, 'brakes');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 faults'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
        find.byKey(const ValueKey('fault-search-input')), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No faults match your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
