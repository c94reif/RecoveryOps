import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/data/services/static_pmcs_catalog_source.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/domain/services/pmcs_catalog_source.dart';
import 'package:ivy_pulse/presentation/home/home_page.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/profile/profile_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';
import 'package:ivy_pulse/presentation/reports/reports_page.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

/// The shell mounts all three tabs at once, so the PMCS tab needs a view model
/// that parks on the setup screen without touching a database or a catalog
/// beyond the one the picker reads.
class FakeInspectionViewModel extends ChangeNotifier
    implements InspectionViewModel {
  @override
  final PmcsCatalogSource catalogSource = const StaticPmcsCatalogSource();

  @override
  InspectionStage stage = InspectionStage.setup;

  @override
  List<PmcsSession> openSessions = [];

  @override
  VehicleType selectedVehicle = VehicleType.stryker;

  @override
  bool isBusy = false;

  @override
  Profile? profile;

  int loadCalls = 0;

  @override
  Future<void> load() async {
    loadCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeReportsViewModel reportsViewModel;
  late FakeInspectionViewModel inspectionViewModel;

  setUp(() async {
    await getIt.reset();
    reportsViewModel = FakeReportsViewModel();
    inspectionViewModel = FakeInspectionViewModel();

    getIt.registerLazySingleton<HomeViewModel>(() => HomeViewModel());
    getIt.registerLazySingleton<ReportsViewModel>(() => reportsViewModel);
    getIt.registerLazySingleton<InspectionViewModel>(
      () => inspectionViewModel,
    );
    getIt.registerLazySingleton<ProfileRepository>(
      () => FakeProfileRepository(),
    );
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(getIt<ProfileRepository>()),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget subject() => MaterialApp(theme: appTheme, home: const HomePage());

  int? visibleTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  group('the tab bar', () {
    testWidgets('offers PMCS, Reports and Profile', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('PMCS'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl), findsOneWidget);
      expect(find.byIcon(Icons.assignment_late_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('opens on the PMCS walk-around', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(visibleTab(tester), 0);
    });

    testWidgets('tapping Reports shows the reports tab', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(visibleTab(tester), 1);
      expect(find.byType(ReportsPage), findsOneWidget);
    });

    testWidgets('tapping Profile shows the profile tab', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(visibleTab(tester), 2);
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('coming back to PMCS does not restart the inspection',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      final loadsAfterFirstBuild = inspectionViewModel.loadCalls;

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PMCS'));
      await tester.pumpAndSettle();

      expect(visibleTab(tester), 0);
      expect(inspectionViewModel.loadCalls, loadsAfterFirstBuild);
    });

    testWidgets('the selected tab is the only one tinted', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.text('PMCS')).style!.color,
          masterChiefGreen);
      expect(tester.widget<Text>(find.text('Reports')).style!.color,
          textSecondary);

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(
          tester.widget<Text>(find.text('PMCS')).style!.color, textSecondary);
      expect(tester.widget<Text>(find.text('Reports')).style!.color,
          masterChiefGreen);
    });

    testWidgets('every tab clears the gloved-thumb touch target',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      for (final label in ['PMCS', 'Reports', 'Profile']) {
        expect(
          tester
              .getSize(find.ancestor(
                of: find.text(label),
                matching: find.byType(GestureDetector),
              ))
              .height,
          greaterThanOrEqualTo(minTouchTarget),
        );
      }
    });
  });

  group('the unread badge', () {
    testWidgets('is absent while nothing has come in', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('counts PMCS from other crews that have not been opened',
        (tester) async {
      reportsViewModel.unreadCount.value = 3;

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Badge, '3'), findsOneWidget);
    });

    testWidgets('appears the moment a report arrives, without a tab change',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.byType(Badge), findsNothing);

      reportsViewModel.unreadCount.value = 1;
      await tester.pump();

      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
    });

    testWidgets('clears again once the reports are read', (tester) async {
      reportsViewModel.unreadCount.value = 2;
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.byType(Badge), findsOneWidget);

      reportsViewModel.unreadCount.value = 0;
      await tester.pump();

      expect(find.byType(Badge), findsNothing);
    });
  });
}
