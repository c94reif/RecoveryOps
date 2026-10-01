import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/presentation/common/widgets/pmcs_report_card.dart';
import 'package:circle_x/presentation/maintainer/maintainer_page.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

PmcsReport signedReview(PmcsReport source,
        {required String id,
        required String name,
        required DateTime signedAt,
        required String note,
        List<FaultReview>? decisions}) =>
    buildReport(
        entityId: id,
        faults: source.faults,
        maintainerReview: MaintainerReview(
          sourceReportId: source.entityId,
          signature: buildSignature(
              identity: buildIdentity(lastName: name), signedAt: signedAt),
          faults: decisions ??
              [
                for (final fault in source.faults)
                  FaultReview(
                      itemId: fault.itemId,
                      phase: fault.phase,
                      verified: fault == source.faults.first,
                      description: note)
              ],
        ));

class PendingReportsViewModel extends FakeReportsViewModel {
  final pending = Completer<List<PmcsReport>>();

  @override
  Future<void> syncRemoteLatticeReports() async {
    syncCalls++;
    reports.addAll(await pending.future);
    notifyListeners();
  }
}

void main() {
  late FakeReportsViewModel viewModel;

  setUp(() async {
    await getIt.reset();
    viewModel = FakeReportsViewModel();
    getIt.registerSingleton<ReportsViewModel>(viewModel);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MaintainerPage(onExit: () {})),
      );

  testWidgets('triage shows only latest reports with faults, most severe first',
      (tester) async {
    viewModel.reports.addAll([
      buildReport(
        entityId: 'old-deadline',
        timestamp: DateTime.utc(2026, 1, 1),
        faults: [buildFault(severity: FaultSeverity.redX)],
      ),
      buildReport(
        entityId: 'latest-clear',
        timestamp: DateTime.utc(2026, 1, 2),
      ),
      buildReport(
        entityId: 'received-deadline',
        bumperNumber: 'B-22',
        isOutgoing: false,
        faults: [buildFault(severity: FaultSeverity.redX)],
      ),
      buildReport(
          entityId: 'pending-minor',
          bumperNumber: 'C-33',
          faults: [buildFault(severity: FaultSeverity.dash)]),
    ]);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('2 vehicles awaiting review'), findsOneWidget);
    expect(
        tester
            .widgetList<PmcsReportCard>(find.byType(PmcsReportCard))
            .first
            .report
            .entityId,
        'received-deadline');
    expect(find.text('NOT REVIEWED'), findsWidgets);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pending-minor')), 160,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-minor')), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.byKey(const ValueKey('latest-clear')), findsNothing);
    expect(find.byKey(const ValueKey('old-deadline')), findsNothing);
  });

  testWidgets('search separates matching bumper numbers in different units',
      (tester) async {
    viewModel.reports.addAll([
      buildReport(entityId: 'unit-a', uic: 'WJ8TAA', faults: [buildFault()]),
      buildReport(entityId: 'unit-b', uic: 'WAB4C0', faults: [buildFault()]),
    ]);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('2 vehicles awaiting review'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' wab4c0 ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unit-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('unit-a')), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No pending reviews match your search.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a-11');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('unit-b')), 160,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.byType(PmcsReportCard), findsNWidgets(2));
  });

  testWidgets('incoming reports, fault notes and refresh use the shared data',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.textContaining('No PMCS reports yet.'), findsOneWidget);

    await viewModel.addOutgoing(buildReport(
      entityId: 'new-report',
      isOutgoing: false,
      isRead: false,
      faults: [buildFault(note: 'Oil pooling beneath the engine.')],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View operator notes'));
    await tester.pumpAndSettle();
    expect(find.text('Operator note: Oil pooling beneath the engine.'),
        findsOneWidget);
    expect(viewModel.markedRead.single.entityId, 'new-report');
    await tester.tap(find.byTooltip('Refresh reports'));
    await tester.pumpAndSettle();
    expect(viewModel.syncCalls, 2);
    expect(viewModel.deleted, isEmpty);
  });

  testWidgets('entry checks immediately and search includes arriving reports',
      (tester) async {
    final pendingModel = PendingReportsViewModel();
    await getIt.unregister<ReportsViewModel>();
    getIt.registerSingleton<ReportsViewModel>(pendingModel);
    pendingModel.reports
        .add(buildReport(entityId: 'local', faults: [buildFault()]));

    await tester.pumpWidget(subject());
    await tester.pump();
    expect(pendingModel.syncCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('local')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'b-22');
    await tester.pump();
    pendingModel.pending.complete([
      buildReport(
          entityId: 'remote',
          bumperNumber: 'B-22',
          isOutgoing: false,
          faults: [buildFault()]),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('remote')), findsOneWidget);
    expect(find.byKey(const ValueKey('local')), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'b-22');
    expect(pendingModel.syncCalls, 1);
  });

  testWidgets('leaving while the entry check is pending is safe',
      (tester) async {
    final pendingModel = PendingReportsViewModel();
    await getIt.unregister<ReportsViewModel>();
    getIt.registerSingleton<ReportsViewModel>(pendingModel);

    await tester.pumpWidget(subject());
    await tester.pump();
    expect(pendingModel.syncCalls, 1);
    await tester.pumpWidget(const SizedBox());
    pendingModel.pending.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('maintainer controls fit a narrow panel with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    viewModel.reports.add(buildReport(faults: [buildFault()]));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit maintainer mode'), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a received signed batch clears the queue without deleting reports',
      (tester) async {
    final source =
        buildReport(faults: [buildFault(), buildFault(itemId: 'brakes')]);
    viewModel.reports.add(source);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    await viewModel.addOutgoing(signedReview(source,
            id: 'received-review',
            name: 'PEER',
            signedAt: DateTime.utc(2026, 9, 30),
            note: 'Reviewed on peer.')
        .copyWith(isOutgoing: false));
    await tester.pumpAndSettle();
    expect(find.byType(PmcsReportCard), findsNothing);
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('0 vehicles awaiting review'), findsOneWidget);
    expect(viewModel.reports, hasLength(2));
    expect(viewModel.deleted, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets(
      'a new PMCS returns to the queue and reviewing it never exposes older reports',
      (tester) async {
    final old = buildReport(
        entityId: 'old',
        faults: [buildFault()],
        timestamp: DateTime.utc(2026, 9, 28));
    final source = buildReport(
        entityId: 'current',
        faults: [buildFault()],
        timestamp: DateTime.utc(2026, 9, 29));
    viewModel.reports.addAll([
      old,
      source,
      signedReview(source,
          id: 'signed-current',
          name: 'MAINTAINER',
          signedAt: DateTime.utc(2026, 9, 30),
          note: 'Reviewed.')
    ]);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
    final next = buildReport(
        entityId: 'next',
        faults: source.faults,
        timestamp: DateTime.utc(2026, 10, 1));
    await viewModel.addOutgoing(next);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
    expect(find.text('1 vehicle awaiting review'), findsOneWidget);
    await viewModel.addOutgoing(signedReview(next,
        id: 'signed-next',
        name: 'MAINTAINER',
        signedAt: DateTime.utc(2026, 10, 1),
        note: 'Reviewed again.'));
    await tester.pumpAndSettle();
    expect(find.byType(PmcsReportCard), findsNothing);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets(
      'partial batches and decisions for another phase do not clear a PMCS',
      (tester) async {
    final source = buildReport(faults: [
      buildFault(itemId: 'engine', phase: PmcsPhase.before),
      buildFault(itemId: 'engine', phase: PmcsPhase.during),
    ]);
    viewModel.reports.addAll([
      source,
      signedReview(source,
          id: 'partial',
          name: 'MAINTAINER',
          signedAt: DateTime.utc(2026, 9, 30),
          note: '',
          decisions: const [
            FaultReview(
                itemId: 'engine', phase: PmcsPhase.before, verified: false)
          ]),
      signedReview(source,
          id: 'wrong-phase',
          name: 'MAINTAINER',
          signedAt: DateTime.utc(2026, 9, 30),
          note: '',
          decisions: const [
            FaultReview(
                itemId: 'engine', phase: PmcsPhase.before, verified: false),
            FaultReview(
                itemId: 'engine', phase: PmcsPhase.after, verified: false),
          ])
    ]);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.byType(PmcsReportCard), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    await viewModel.addOutgoing(signedReview(source,
        id: 'complete',
        name: 'MAINTAINER',
        signedAt: DateTime.utc(2026, 9, 30),
        note: '',
        decisions: const [
          FaultReview(
              itemId: 'engine', phase: PmcsPhase.before, verified: false),
          FaultReview(
              itemId: 'engine', phase: PmcsPhase.during, verified: false),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });
}
