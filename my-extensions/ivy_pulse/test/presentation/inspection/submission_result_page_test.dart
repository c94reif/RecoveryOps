import 'package:ivy_pulse/data/services/main_thread_queue_worker.dart';

import '../../data/main_thread_queue_worker_test.dart'

    show FakeQueuePromptStrategy;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/home/home_page.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/phase_select_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;
  late FakeReportsViewModel reports;
  late HomeViewModel home;
  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    reports = FakeReportsViewModel();
    harness = InspectionHarness(onReportSubmitted: reports.addOutgoing);
    harness.register();
    home = HomeViewModel();
    getIt.registerSingleton<HomeViewModel>(home);
    getIt.registerSingleton<ReportsViewModel>(reports);
    getIt.registerSingleton<ProfileRepository>(harness.profiles);
    getIt.registerFactory<ProfileViewModel>(
        () => ProfileViewModel(harness.profiles));
  });
  tearDown(() async {
    await getIt.reset();
    clearSnackBars();
  });

  Future<void> ready(WidgetTester tester) async {
    await tester
        .pumpWidget(MaterialApp(theme: appTheme, home: const HomePage()));
    await tester.pumpAndSettle();
    await harness.walkToSummary();
  }

  testWidgets(
      'the saved receipt shows delivery progress and opens the exact report',
      (tester) async {
    await ready(tester);
    final gate = Completer<bool>();
    harness.entityPort.publishGate = gate;
    await harness.viewModel.submitWith(buildSignature());
    await tester.pumpAndSettle();
    expect(find.text('PMCS saved'), findsOneWidget);
    expect(find.text('Lattice · Sending…'), findsOneWidget);
    expect(find.text('Mesh · Sent'), findsOneWidget);
    expect(harness.reports.reports, hasLength(1));

    gate.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Lattice · Queued'), findsOneWidget);
    expect(find.text('Mesh · Sent'), findsOneWidget);

    await tester.tap(find.text('View report'));
    await tester.pumpAndSettle();
    expect(home.pageIndex, 1);
    expect(find.text('A-11 - Stryker'), findsOneWidget);
    expect(find.text('New PMCS'), findsOneWidget);

    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();
    expect(home.pageIndex, 0);
    expect(find.byType(PhaseSelectPage), findsOneWidget);
    expect(harness.viewModel.stage, InspectionStage.phaseSelect);
    expect(harness.viewModel.submittedReport, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a publishing error keeps the saved report available',
      (tester) async {
    await ready(tester);
    final gate = Completer<bool>();
    harness.entityPort.publishGate = gate;
    await harness.viewModel.submitWith(buildSignature());
    gate.completeError(StateError('transport unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('PMCS saved'), findsOneWidget);
    expect(find.text('Lattice · Queued'), findsOneWidget);
    expect(find.text('Mesh · Sent'), findsOneWidget);
    expect(harness.queueWorker.enqueued, hasLength(1));
    expect(harness.reports.reports, hasLength(1));
    expect(find.text('View report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queued retry updates the open receipt to sent',
      (tester) async {
    await ready(tester);
    harness.entityPort.publishSucceeds = false;
    await harness.viewModel.submitWith(buildSignature());
    await tester.pumpAndSettle();
    expect(find.text('Lattice · Queued'), findsOneWidget);
    final worker = MainThreadQueueWorker(
      repository: FakeQueuedSubmissionsRepository(),
      entityPort: harness.entityPort,
      meshPort: harness.meshPort,
      promptStrategy: FakeQueuePromptStrategy(),
      delivery: harness.viewModel.publishPmcsReport.delivery,
    );
    addTearDown(worker.stop);
    await worker.enqueue(harness.queueWorker.enqueued.single);
    harness.entityPort.publishSucceeds = true;
    await worker.nudge(harness.queueWorker.enqueued.single.transport);
    await tester.pumpAndSettle();
    expect(find.text('Lattice · Sent'), findsOneWidget);
    expect(find.text('Mesh · Sent'), findsOneWidget);
    expect(find.textContaining('Queued delivery will retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a receipt ignores late delivery updates',
      (tester) async {
    await ready(tester);
    final gate = Completer<bool>();
    harness.entityPort.publishGate = gate;
    await harness.viewModel.submitWith(buildSignature());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start another PMCS'));
    await tester.pumpAndSettle();
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(harness.viewModel.stage, InspectionStage.setup);
    expect(harness.viewModel.submissionDelivery, isNull);
    expect(find.text('BEGIN PMCS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
