import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/data/dao/faults/pmcs_faults_dao.dart';
import 'package:ivy_pulse/data/dao/reports/pmcs_reports_dao.dart';
import 'package:ivy_pulse/data/dao/results/check_results_dao.dart';
import 'package:ivy_pulse/data/dao/sessions/sessions_dao.dart';
import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/data/repositories/faults_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/reports_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/results_repo_impl.dart';
import 'package:ivy_pulse/data/repositories/sessions_repo_impl.dart';
import 'package:ivy_pulse/data/services/static_pmcs_catalog_source.dart';
import 'package:ivy_pulse/data/services/tm_fault_classifier.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';
import 'package:ivy_pulse/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/build_session_report.dart';
import 'package:ivy_pulse/domain/usecases/reporting/submit_session.dart';
import 'package:ivy_pulse/domain/usecases/session/abandon_session.dart';
import 'package:ivy_pulse/domain/usecases/session/complete_phase.dart';
import 'package:ivy_pulse/domain/usecases/session/load_open_sessions.dart';
import 'package:ivy_pulse/domain/usecases/session/record_check_result.dart';
import 'package:ivy_pulse/domain/usecases/session/start_session.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/inspection/check_item_card.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_flow_page.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:latlong2/latlong.dart';

import '../../support/fakes.dart';

/// Walks the real flow over the real TM catalogs and a real database, because
/// the one failure that matters most here is the checklist coming up empty.
void main() {
  late AppDatabase db;

  late FakeCacScanner cacScanner;

  setUp(() async {
    await getIt.reset();
    SnackBarService.instance.queue.clear();
    cacScanner = FakeCacScanner();

    db = AppDatabase.test(NativeDatabase.memory());
    final sessions = SessionsRepoImpl(SessionsDao(db));
    final results = ResultsRepoImpl(CheckResultsDao(db));
    final faults = FaultsRepoImpl(PmcsFaultsDao(db));
    final reports = ReportsRepoImpl(PmcsReportsDao(db));
    final clock = FixedClock(DateTime.utc(2026, 3, 24, 6));

    // InspectionPage resolves the classifier itself so each fault button can
    // show the grading it would carry.
    getIt.registerLazySingleton<FaultClassifierStrategy>(
      () => const TmFaultClassifier(),
    );

    getIt.registerLazySingleton<InspectionViewModel>(
      () => InspectionViewModel(
        catalogSource: const StaticPmcsCatalogSource(),
        startSession: StartSession(
          repository: sessions,
          locationRepository: FakeLocationRepository(const LatLng(33, -84)),
          clock: clock,
          idGenerator: FakeIdGenerator(['session-1']),
        ),
        loadOpenSessions: LoadOpenSessions(sessions),
        recordCheckResult: RecordCheckResult(
          repository: results,
          classifier: const TmFaultClassifier(),
          clock: clock,
        ),
        completePhase: CompletePhase(
          sessionsRepository: sessions,
          faultsRepository: faults,
        ),
        abandonSession: AbandonSession(
          sessionsRepository: sessions,
          resultsRepository: results,
          faultsRepository: faults,
        ),
        submitSession: SubmitSession(
          sessionsRepository: sessions,
          faultsRepository: faults,
          reportsRepository: reports,
          buildSessionReport: BuildSessionReport(clock),
          clock: clock,
        ),
        publishPmcsReport: PublishPmcsReport(
          entityPort: FakePmcsEntityPort(),
          meshPort: FakeMeshBroadcaster(),
          queueWorker: FakeQueueWorker(),
          codec: FakeReportCodec(),
          clock: clock,
        ),
        resultsRepository: results,
        faultsRepository: faults,
        speechStrategy: FakeSpeech(),
        verifyOperatorIdentity: VerifyOperatorIdentity(
          scanner: cacScanner,
          parseBarcode: ParseCacBarcode(clock),
        ),
        cacScanner: cacScanner,
        profileRepository: FakeProfileRepository(
          const Profile(uic: 'WJ8TAA'),
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await getIt.reset();
  });

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: InspectionFlowPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> beginPmcs(WidgetTester tester, VehicleType vehicle) async {
    final viewModel = getIt<InspectionViewModel>();
    viewModel.selectVehicle(vehicle);
    await viewModel.beginSession(
      bumperNumber: 'A-11',
      uic: 'WJ8TAA',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phase cards report the real TM check counts', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFlow(tester);
    await beginPmcs(tester, VehicleType.stryker);

    expect(find.text('Before Operations'), findsOneWidget);
    expect(find.textContaining('44'), findsWidgets);
  });

  testWidgets('opening a phase renders the TM checks', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFlow(tester);
    await beginPmcs(tester, VehicleType.stryker);

    await getIt<InspectionViewModel>().openPhase(PmcsPhase.before);
    await tester.pumpAndSettle();

    // The first walk-around station and its first TM check.
    expect(find.text('EXTERIOR / HULL'), findsOneWidget);
    expect(find.text('B-EXT-01'), findsOneWidget);
    expect(find.text('Hull & Body Panels'), findsOneWidget);
    expect(
      find.text('Inspect hull for cracks, dents, holes, or battle damage'),
      findsOneWidget,
    );
    // Its conditions, serviceable first.
    expect(find.text('NO DAMAGE'), findsOneWidget);
    expect(find.text('Cracks Found'), findsOneWidget);
  });

  testWidgets('the JLTV catalog renders its own TM checks', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFlow(tester);
    await beginPmcs(tester, VehicleType.jltv);

    await getIt<InspectionViewModel>().openPhase(PmcsPhase.before);
    await tester.pumpAndSettle();

    expect(find.text('DRIVER SIDE FRONT'), findsOneWidget);
    expect(find.text('JLTV-CRIT-B01'), findsOneWidget);
    expect(find.text('Wheel/Tire'), findsWidgets);
  });

  testWidgets('answering a check collapses it and shows the grading',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFlow(tester);
    await beginPmcs(tester, VehicleType.stryker);

    final viewModel = getIt<InspectionViewModel>();
    await viewModel.openPhase(PmcsPhase.before);
    await tester.pumpAndSettle();

    await tester.tap(find.text('NO DAMAGE'));
    await tester.pumpAndSettle();

    expect(viewModel.answeredCount, 1);
    expect(find.text('OK'), findsOneWidget);
  });

  group('fits the panel the host actually gives us', () {
    // The extension renders in a side panel, not a full screen. Measured on a
    // device it is roughly 470x420 logical pixels in landscape once the host's
    // own title bar is taken out; these tests hold it to a stricter 380x330 so
    // a 5" phone is covered too. The failure being guarded is the one that was
    // reported from the field: the operator could not read the TM check
    // because fixed chrome had squeezed the list to a sliver.
    const panel = Size(380, 330);

    Future<void> pumpPanel(WidgetTester tester) async {
      tester.view.physicalSize = panel;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: SizedBox(
              width: panel.width,
              height: panel.height,
              child: const InspectionFlowPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await beginPmcs(tester, VehicleType.stryker);
      await getIt<InspectionViewModel>().openPhase(PmcsPhase.before);
      await tester.pumpAndSettle();
    }

    CheckItemCard expandedCard(WidgetTester tester) {
      final expanded = tester
          .widgetList<CheckItemCard>(find.byType(CheckItemCard))
          .where((card) => card.isExpanded)
          .toList();
      expect(expanded, hasLength(1),
          reason: 'exactly one check is open at a time');
      return expanded.single;
    }

    testWidgets('only the check being worked is expanded', (tester) async {
      await pumpPanel(tester);

      expect(expandedCard(tester).item.id, 'B-EXT-01');
    });

    testWidgets('the whole open check fits without scrolling', (tester) async {
      await pumpPanel(tester);

      // B-EXT-01's last condition. If the bottom of the last fault button is
      // on screen then the operator can read the instruction, see every
      // condition, and answer without scrolling — which is the whole point.
      final lastOption = find.text('Panels Missing');
      expect(lastOption, findsOneWidget);

      final box = tester.getRect(lastOption);
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(panel.height),
          reason: 'the last condition of the open check is off the panel');
    });

    testWidgets('the TM instruction is on screen, not clipped away',
        (tester) async {
      await pumpPanel(tester);

      final instruction = find.text(
        'Inspect hull for cracks, dents, holes, or battle damage',
      );
      expect(instruction, findsOneWidget);

      final box = tester.getRect(instruction);
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(panel.height));
    });

    testWidgets('fixed chrome leaves most of the panel to the checklist',
        (tester) async {
      await pumpPanel(tester);

      final listHeight =
          tester.getSize(find.byType(SingleChildScrollView)).height;

      expect(listHeight / panel.height, greaterThan(0.7),
          reason: 'header plus any bottom bar should cost under 30% of the '
              'panel while the phase is in progress');
    });

    testWidgets('backing out of a phase does not need a bottom bar',
        (tester) async {
      await pumpPanel(tester);

      expect(find.text('BACK TO PHASES'), findsNothing);
      expect(find.byTooltip('Back to phases'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to phases'));
      await tester.pumpAndSettle();

      expect(getIt<InspectionViewModel>().stage, InspectionStage.phaseSelect);
    });

    testWidgets('answering opens the next check and leaves the last as a row',
        (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.text('NO DAMAGE'));
      await tester.pumpAndSettle();

      expect(expandedCard(tester).item.id, 'B-EXT-02');
    });

    testWidgets('a long JLTV instruction still leaves its conditions reachable',
        (tester) async {
      // JLTV checks carry multi-sentence TM instructions — the tallest cards
      // in either catalog. They will not fit whole on a 330px panel, so the
      // requirement is weaker but still firm: the instruction starts on screen
      // and the conditions are scrollable to, not clipped out of the tree.
      tester.view.physicalSize = panel;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: SizedBox(
              width: panel.width,
              height: panel.height,
              child: const InspectionFlowPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await beginPmcs(tester, VehicleType.jltv);
      await getIt<InspectionViewModel>().openPhase(PmcsPhase.before);
      await tester.pumpAndSettle();

      final open = expandedCard(tester);
      expect(open.item.id, 'JLTV-CRIT-B01');

      expect(find.text(open.item.check), findsOneWidget);
      expect(tester.getRect(find.text(open.item.check)).top,
          greaterThanOrEqualTo(0.0));

      // The serviceable answer is the common case and must never need a
      // scroll, however long the instruction above it runs.
      final serviceable = find.text(open.item.serviceableLabel.toUpperCase());
      expect(serviceable, findsOneWidget);
      expect(
          tester.getRect(serviceable).bottom, lessThanOrEqualTo(panel.height),
          reason: 'the serviceable answer is off the panel');
    });

    testWidgets('a check part-way down the phase is scrolled fully into view',
        (tester) async {
      // The report from the field was at 16 of 44, not at the first check:
      // the open card had been scrolled to but hung off the bottom of the
      // panel. Answer a run of checks and assert the one now open is whole.
      await pumpPanel(tester);

      final viewModel = getIt<InspectionViewModel>();
      for (var i = 0; i < 8; i++) {
        final open = expandedCard(tester).item;
        await viewModel.answer(open, 0);
        await tester.pumpAndSettle();
      }

      final open = expandedCard(tester);
      expect(viewModel.answeredCount, 8);

      final instruction = find.text(open.item.check);
      final lastOption = find.text(open.item.faults.last);
      expect(instruction, findsOneWidget);
      expect(lastOption, findsOneWidget);

      expect(tester.getRect(instruction).top, greaterThanOrEqualTo(0.0),
          reason: 'the TM instruction is scrolled off the top');
      expect(tester.getRect(lastOption).bottom, lessThanOrEqualTo(panel.height),
          reason: 'the last condition hangs off the bottom of the panel');
    });

    testWidgets(
        'resuming a phase scrolls to an unanswered check far down the list',
        (tester) async {
      await pumpPanel(tester);
      final viewModel = getIt<InspectionViewModel>();
      for (final item in viewModel.phaseItems.take(20).toList()) {
        await viewModel.answer(item, 0);
      }
      viewModel.backToPhases();
      await tester.pumpAndSettle();
      await viewModel.openPhase(PmcsPhase.before);
      await tester.pumpAndSettle();

      expect(viewModel.answeredCount, 20);
      final open = expandedCard(tester);
      expect(open.item.id, viewModel.nextUnansweredItemId);
      final instruction = tester.getRect(find.text(open.item.check));
      expect(instruction.top, greaterThanOrEqualTo(0));
      expect(instruction.bottom, lessThan(panel.height));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Dictation is not exercised here; the flow only needs a strategy to exist.
class FakeSpeech implements SpeechRecognitionStrategy {
  @override
  bool get isListening => false;

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {}

  @override
  Future<void> stopListening() async {}
}
