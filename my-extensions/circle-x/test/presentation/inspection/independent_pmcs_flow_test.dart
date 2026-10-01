import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/presentation/inspection/inspection_flow_page.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';

import '../../support/cac_fixtures.dart';
import '../../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    harness = InspectionHarness();
    harness.register();
  });

  tearDown(() async {
    await getIt.reset();
    clearSnackBars();
  });

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final phase in PmcsPhase.values) {
    for (final withFault in [false, true]) {
      testWidgets(
          '${phase.wireName} alone can be signed, saved and sent '
          '${withFault ? 'with a fault' : 'without faults'}', (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await harness.begin();
        await tester.pumpWidget(MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: InspectionFlowPage()),
        ));
        await tester.pumpAndSettle();

        await tap(tester, phase.label);
        expect(harness.viewModel.stage, InspectionStage.inspecting);
        expect(find.text('REVIEW & SUBMIT'), findsNothing);

        final items = harness.viewModel.phaseItems;
        for (var i = 0; i < items.length; i++) {
          final faultIndex = withFault && i == 0 ? 3 : 0;
          final label = items[i].faults[faultIndex];
          await tap(tester, faultIndex == 0 ? label.toUpperCase() : label);
        }
        final hasRedX = withFault && phase == PmcsPhase.before;
        await tap(
            tester, hasRedX ? 'REVIEW & SUBMIT — RED X' : 'REVIEW & SUBMIT');

        expect(harness.viewModel.stage, InspectionStage.summary);
        expect(harness.viewModel.session!.completedPhases, [phase]);
        expect(find.text('${phase.label} PMCS'), findsOneWidget);
        for (final other in PmcsPhase.values.where((value) => value != phase)) {
          expect(find.textContaining(other.label), findsNothing);
        }
        expect(find.textContaining('remaining'), findsNothing);
        expect(find.text('SUBMIT PMCS'), findsNothing);

        // A restart after finishing one checklist returns to sign-off directly.
        final draft = harness.viewModel.session!;
        await harness.viewModel.resetToSetup();
        await harness.viewModel.resumeSession(draft);
        await tester.pumpAndSettle();
        expect(harness.viewModel.stage, InspectionStage.summary);

        await tap(tester, 'Review checks');
        expect(harness.viewModel.activePhase, phase);
        expect(harness.viewModel.answeredCount, items.length);
        await tester.tap(find.byTooltip('Back to summary'));
        await tester.pumpAndSettle();
        expect(harness.viewModel.stage, InspectionStage.summary);

        harness.cacScanner.willRead(cacBarcode());
        await tap(tester, 'SCAN CAC');
        await tap(tester, 'SUBMIT PMCS');

        final report = harness.reports.reports.single;
        expect(report.phases, [phase]);
        expect(report.faults, hasLength(withFault ? 1 : 0));
        if (withFault) {
          expect(report.faults.single.phase, phase);
          expect(report.faults.single.itemId, items.first.id);
          expect(report.isDeadlined, hasRedX);
        }
        expect(report.isSignatureVerified, isTrue);
        expect(harness.entityPort.published.single, same(report));
        expect(harness.meshPort.broadcast.single, same(report));
        expect(harness.queueWorker.enqueued, isEmpty);
        expect((await harness.sessions.getBySessionId(draft.sessionId))!.status,
            SessionStatus.submitted);
        expect(harness.viewModel.stage, InspectionStage.submitted);
        expect(find.text('PMCS saved'), findsOneWidget);
        expect(harness.viewModel.session, isNull);

        await tap(tester, 'Start another PMCS');
        expect(harness.viewModel.stage, InspectionStage.setup);
        expect(find.text('RESUME PMCS'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
