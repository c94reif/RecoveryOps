import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';
import 'package:recovery_ops/presentation/home/homeViewModel.dart';
import 'package:recovery_ops/presentation/navigation/navigationPage.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';

class FakeLocationRepository implements LocationRepository {
  @override
  Future<LatLng?> getCurrentLocation() async => null;
}

class FakeNavigationViewModel extends ChangeNotifier
    implements NavigationViewModel {
  RecoveryReport? fakeNavigatingReport;
  LatLng? fakeCurrentLocation;
  bool stopNavigationCalled = false;

  @override
  RecoveryReport? get navigatingReport => fakeNavigatingReport;

  @override
  LatLng? get currentLocation => fakeCurrentLocation;

  @override
  void stopNavigation() {
    stopNavigationCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHomeViewModel extends HomeViewModel {
  int? selectedTab;

  FakeHomeViewModel() : super(FakeLocationRepository());

  @override
  void selectTab(int index) {
    selectedTab = index;
  }
}

RecoveryReport makeReport({
  String bumperNumber = 'HQ-42',
  String recoveryType = 'Wrecker',
  String fromCallsign = 'Ghost',
  double latitude = 33.0,
  double longitude = -84.0,
}) {
  return RecoveryReport(
    bumperNumber: bumperNumber,
    issue: 'flat tire',
    recoveryType: recoveryType,
    fromCallsign: fromCallsign,
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 3, 24, 12, 0),
  );
}

void main() {
  late FakeNavigationViewModel navVm;
  late FakeHomeViewModel homeVm;

  setUp(() async {
    await getIt.reset();
    navVm = FakeNavigationViewModel();
    homeVm = FakeHomeViewModel();

    getIt.registerLazySingleton<NavigationViewModel>(() => navVm);
    getIt.registerLazySingleton<HomeViewModel>(() => homeVm);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createWidget() {
    return const MaterialApp(
      home: Scaffold(body: NavigationPage()),
    );
  }

  group('not navigating', () {
    testWidgets('shows placeholder when no report', (tester) async {
      navVm.fakeCurrentLocation = const LatLng(34.0, -85.0);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Not currently navigating'), findsOneWidget);
    });

    testWidgets('shows placeholder when no location', (tester) async {
      navVm.fakeNavigatingReport = makeReport();
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Not currently navigating'), findsOneWidget);
    });

    testWidgets('shows placeholder when both are null', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Not currently navigating'), findsOneWidget);
    });
  });

  group('navigating', () {
    setUp(() {
      navVm.fakeNavigatingReport = makeReport();
      navVm.fakeCurrentLocation = const LatLng(34.0, -85.0);
    });

    testWidgets('shows bumper number and recovery type', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('HQ-42 — Wrecker'), findsOneWidget);
    });

    testWidgets('shows from callsign', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('From Ghost'), findsOneWidget);
    });

    testWidgets('shows navigation arrow icon', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });

    testWidgets('shows bearing and cardinal direction', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.textContaining('SE'), findsOneWidget);
    });

    testWidgets('shows distance', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.straighten), findsOneWidget);
      expect(find.textContaining('km'), findsOneWidget);
    });

    testWidgets('shows distance in meters when close', (tester) async {
      navVm.fakeCurrentLocation = const LatLng(33.0001, -84.0001);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining(' m'), findsOneWidget);
    });

    testWidgets('shows Stop Navigation button', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Stop Navigation'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });
  });

  group('stop navigation', () {
    testWidgets('calls stopNavigation on view model', (tester) async {
      navVm.fakeNavigatingReport = makeReport();
      navVm.fakeCurrentLocation = const LatLng(34.0, -85.0);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop Navigation'));
      await tester.pumpAndSettle();

      expect(navVm.stopNavigationCalled, isTrue);
    });

    //TODO: This test is passing when it shouldn't...
    testWidgets('switches to Reports tab', (tester) async {
      navVm.fakeNavigatingReport = makeReport();
      navVm.fakeCurrentLocation = const LatLng(34.0, -85.0);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop Navigation'));
      await tester.pumpAndSettle();

      expect(homeVm.selectedTab, 1);
    });
  });

  group('bearing calculation', () {
    const page = NavigationPage();

    test('north is 0 degrees', () {
      final bearing =
          page.calculateBearing(const LatLng(33.0, -84.0), const LatLng(34.0, -84.0));
      expect(bearing, closeTo(0, 1));
    });

    test('east is 90 degrees', () {
      final bearing =
          page.calculateBearing(const LatLng(33.0, -85.0), const LatLng(33.0, -84.0));
      expect(bearing, closeTo(90, 1));
    });

    test('south is 180 degrees', () {
      final bearing =
          page.calculateBearing(const LatLng(34.0, -84.0), const LatLng(33.0, -84.0));
      expect(bearing, closeTo(180, 1));
    });

    test('west is 270 degrees', () {
      final bearing =
          page.calculateBearing(const LatLng(33.0, -84.0), const LatLng(33.0, -85.0));
      expect(bearing, closeTo(270, 1));
    });
  });

  group('cardinal direction', () {
    const page = NavigationPage();

    test('0 degrees is N', () => expect(page.cardinalDirection(0), 'N'));
    test('45 degrees is NE', () => expect(page.cardinalDirection(45), 'NE'));
    test('90 degrees is E', () => expect(page.cardinalDirection(90), 'E'));
    test('135 degrees is SE', () => expect(page.cardinalDirection(135), 'SE'));
    test('180 degrees is S', () => expect(page.cardinalDirection(180), 'S'));
    test('225 degrees is SW', () => expect(page.cardinalDirection(225), 'SW'));
    test('270 degrees is W', () => expect(page.cardinalDirection(270), 'W'));
    test('315 degrees is NW', () => expect(page.cardinalDirection(315), 'NW'));
    test('359 degrees is N', () => expect(page.cardinalDirection(359), 'N'));
  });
}
