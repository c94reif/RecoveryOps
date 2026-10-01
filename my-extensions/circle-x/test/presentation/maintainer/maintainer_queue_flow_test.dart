import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/entities/transport_kind.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/id_generator.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/common/widgets/pmcs_report_card.dart';
import 'package:circle_x/presentation/maintainer/maintainer_page.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';
import '../../support/fakes.dart';
import '../../support/maintainer_harness.dart';

void main() {
  late MaintainerHarness h;
  late FakeReportsViewModel reports;
  setUp(() async {
    await getIt.reset();
    h = MaintainerHarness();
    reports = FakeReportsViewModel()..reports.add(h.report);
    getIt.registerSingleton<ReportsViewModel>(reports);
    getIt.registerSingleton<IdGenerator>(FakeIdGenerator());
    getIt.registerSingleton<CacScannerStrategy>(h.scanner);
    getIt.registerSingleton<SpeechRecognitionStrategy>(h.speech);
    getIt.registerSingleton<VerifyOperatorIdentity>(h.verify(h.scanner));
    getIt.registerSingleton<SubmitMaintainerReview>(h.submit);
    getIt.registerSingleton<PublishPmcsReport>(h.publish);
  });
  tearDown(() => getIt.reset());

  Widget subject() => MaterialApp(
      theme: appTheme, home: Scaffold(body: MaintainerPage(onExit: () {})));

  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.text(label).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'CAC submission clears pending work offline and preserves both delivery attempts',
      (tester) async {
    h.store.publishSucceeds = false;
    h.peers.broadcastSucceeds = false;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    await tap(tester, 'Review faults');
    expect(find.text('Not reviewed'), findsOneWidget);
    await tap(tester, 'Not verified');
    expect(find.text('Not reviewed'), findsOneWidget);
    await tap(tester, 'Not verified');
    expect(find.text('Fault 2 of 2'), findsOneWidget);
    expect(find.textContaining('2 of 2 reviewed.'), findsOneWidget);
    await tap(tester, 'Sign & submit');
    expect(h.repository.reports, hasLength(1));
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Scan CAC & submit');
    expect(find.textContaining('Pending delivery will retry'), findsOneWidget);
    await tap(tester, 'Done');
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.byType(PmcsReportCard), findsNothing);
    expect(h.repository.reports, hasLength(2));
    expect(h.queue.submissions.map((row) => row.transport).toSet(),
        TransportKind.values.toSet());
    expect(h.store.published, hasLength(1));
    expect(h.peers.broadcast, hasLength(1));
    expect(reports.deleted, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets(
      'rejected CAC and failed save leave the vehicle awaiting a submitted review',
      (tester) async {
    h.scanner.willFail(CacRejection.noCamera);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, 'Review faults');
    await tap(tester, 'Verified');
    await tap(tester, 'Not verified');
    await tap(tester, 'Sign & submit');
    await tap(tester, 'Scan CAC & submit');
    expect(find.textContaining('A CAC scan is required'), findsOneWidget);
    expect(reports.reports, hasLength(1));
    h.scanner.willRead('1087987498');
    h.repository.failInsert = true;
    await tap(tester, 'Scan CAC & submit');
    expect(find.textContaining('Could not save the review.'), findsOneWidget);
    expect(h.queue.submissions, isEmpty);
    await tap(tester, 'Back to review');
    await tester.tap(find.byTooltip('Back to maintainer'));
    await tester.pumpAndSettle();
    await tap(tester, 'Discard');
    expect(find.text('1 vehicle awaiting review'), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    expect(find.byType(PmcsReportCard), findsOneWidget);
    expect(reports.reports, hasLength(1));
  });
}
