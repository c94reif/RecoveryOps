import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/home/home_page.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/phase_select_page.dart';
import 'package:ivy_pulse/presentation/inspection/setup_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';
import '../../support/inspection_harness.dart';

class ControlledSessionsRepository extends FakeSessionsRepository {
  Completer<void>? insertGate;
  bool failInsert = false;

  @override
  Future<PmcsSession> insert(PmcsSession session) async {
    await insertGate?.future;
    if (failInsert) throw StateError('database unavailable');
    return super.insert(session);
  }
}

void main() {
  late InspectionHarness harness;
  late HomeViewModel home;
  late FakeReportsViewModel reports;
  late ControlledSessionsRepository sessions;

  setUp(() async {
    await getIt.reset();
    clearSnackBars();
    sessions = ControlledSessionsRepository();
    harness = InspectionHarness(sessionsRepository: sessions);
    harness.register();
    home = HomeViewModel();
    reports = FakeReportsViewModel();
    getIt.registerSingleton<HomeViewModel>(home);
    getIt.registerSingleton<ReportsViewModel>(reports);
    getIt.registerSingleton<ProfileRepository>(harness.profiles);
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(harness.profiles),
    );
  });

  tearDown(() async {
    await getIt.reset();
    clearSnackBars();
  });

  Future<void> openReport(WidgetTester tester, PmcsReport report) async {
    reports.reports.add(report);
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: const HomePage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey((
      bumperNumber: report.bumperNumber,
      uic: report.uic,
    ))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New PMCS'));
    await tester.pumpAndSettle();
  }

  for (final vehicle in VehicleType.values) {
    testWidgets(
        'New PMCS opens phase selection with the ${vehicle.displayName} '
        'report vehicle details', (tester) async {
      final report = buildReport(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: vehicle,
        faults: [buildFault()],
      );
      await openReport(tester, report);

      await tester.tap(find.text('New PMCS'));
      await tester.pumpAndSettle();

      expect(home.pageIndex, 0);
      expect(find.byType(PhaseSelectPage), findsOneWidget);
      expect(find.byType(SetupPage), findsNothing);
      expect(find.text('BEGIN PMCS'), findsNothing);
      expect(find.text('B-22 - ${vehicle.displayName}'), findsOneWidget);
      expect(find.text('WAB4C0 · ${vehicle.technicalManual}'), findsOneWidget);
      for (final phase in PmcsPhase.values) {
        expect(find.text(phase.label), findsOneWidget);
      }
      expect(harness.sessions.sessions, hasLength(1));
      final session = harness.sessions.sessions.single;
      expect(session.bumperNumber, report.bumperNumber);
      expect(session.uic, report.uic);
      expect(session.vehicleType, report.vehicleType);
      expect(session.hasStartedAnyPhase, isFalse);
      expect(harness.viewModel.sessionFaults, isEmpty);
      expect(harness.viewModel.catalog?.vehicleType, vehicle);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('repeated taps start only one session', (tester) async {
    await openReport(tester, buildReport());
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'New PMCS'),
    );

    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(harness.sessions.sessions, hasLength(1));
    expect(find.byType(PhaseSelectPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open inspection keeps its vehicle and answers',
      (tester) async {
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 1);
    final session = harness.viewModel.session;
    final workspace = harness.viewModel.workspace;
    await openReport(
      tester,
      buildReport(
        bumperNumber: 'B-22',
        uic: 'WAB4C0',
        vehicleType: VehicleType.jltv,
      ),
    );

    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 1);
    expect(harness.sessions.sessions, hasLength(1));
    expect(harness.viewModel.session, same(session));
    expect(harness.viewModel.workspace, same(workspace));
    expect(harness.viewModel.selectedVehicle, VehicleType.stryker);
    expect(workspace!.resultFor(brakeFluid.id)?.isFault, isTrue);
    expect(find.text('PMCS already in progress'), findsOneWidget);
    expect(find.textContaining('A-11 - Stryker · WJ8TAA'), findsOneWidget);

    await tester.tap(find.text('Continue PMCS'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 0);
    expect(harness.viewModel.stage, InspectionStage.inspecting);
    expect(harness.viewModel.workspace, same(workspace));
    expect(workspace.resultFor(brakeFluid.id)?.isFault, isTrue);
    expect(sessions.sessions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('declining to continue keeps the report and inspection intact',
      (tester) async {
    await harness.begin();
    final session = harness.viewModel.session;
    await openReport(tester, buildReport(bumperNumber: 'B-22'));

    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay in reports'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 1);
    expect(harness.viewModel.session, same(session));
    expect(sessions.sessions, hasLength(1));
    expect(find.text('New PMCS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting feedback remains visible until the session is saved',
      (tester) async {
    await openReport(tester, buildReport());
    sessions.insertGate = Completer<void>();

    await tester.tap(find.text('New PMCS'));
    await tester.pump();

    final starting = find.widgetWithText(OutlinedButton, 'Starting PMCS…');
    expect(starting, findsOneWidget);
    expect(tester.widget<OutlinedButton>(starting).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(home.pageIndex, 1);
    expect(sessions.sessions, isEmpty);

    sessions.insertGate!.complete();
    await tester.pumpAndSettle();

    expect(home.pageIndex, 0);
    expect(sessions.sessions, hasLength(1));
    expect(find.byType(PhaseSelectPage), findsOneWidget);
    expect(find.text('Starting PMCS…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed start clears the busy state and permits retry',
      (tester) async {
    await openReport(tester, buildReport());
    sessions.failInsert = true;

    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 1);
    expect(find.textContaining('Could not start PMCS'), findsOneWidget);
    expect(find.text('Starting PMCS…'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'New PMCS'),
          )
          .onPressed,
      isNotNull,
    );

    sessions.failInsert = false;
    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 0);
    expect(sessions.sessions, hasLength(1));
    expect(find.byType(PhaseSelectPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing vehicle details do not open an invalid session',
      (tester) async {
    await openReport(tester, buildReport(uic: ''));

    await tester.tap(find.text('New PMCS'));
    await tester.pumpAndSettle();

    expect(home.pageIndex, 1);
    expect(harness.sessions.sessions, isEmpty);
    expect(harness.viewModel.stage, InspectionStage.setup);
    expect(find.text('Bumper number and UIC are required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
