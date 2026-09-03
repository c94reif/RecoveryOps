import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';
import 'package:recovery_ops/presentation/reports/reportsPage.dart';


class FakeReportsViewModel extends ChangeNotifier implements ReportsViewModel {
  @override
  final List<RecoveryReport> reports = [];

  @override
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  String? _distanceReturn;
  double? _distanceToKmReturn;
  final List<RecoveryReport> markedAsRead = [];
  final List<RecoveryReport> viewedReports = [];
  final List<RecoveryReport> navigatedReports = [];
  final List<RecoveryReport> deletedReports = [];

  final List<DistanceBracket> bracketMarkedAsRead = [];

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markBracketAsRead(DistanceBracket bracket) async {
    bracketMarkedAsRead.add(bracket);
  }

  @override
  Future<void> markReportAsRead(RecoveryReport report) async {
    markedAsRead.add(report);
  }

  @override
  String? distanceTo(RecoveryReport report) => _distanceReturn;

  @override
  double? distanceToKm(RecoveryReport report) => _distanceToKmReturn;

  @override
  Future<void> viewReport(RecoveryReport report) async {
    viewedReports.add(report);
  }

  @override
  Future<void> navigateTo(RecoveryReport report) async {
    navigatedReports.add(report);
  }

  @override
  Future<void> deleteReport(RecoveryReport report) async {
    deletedReports.add(report);
    reports.remove(report);
    notifyListeners();
  }

  @override
  List<RecoveryReport> get yourReports =>
      reports.where((r) => r.isOutgoing).toList();

  @override
  List<RecoveryReport> get externalReports =>
      reports.where((r) => !r.isOutgoing).toList();

  @override
  Map<DistanceBracket, List<RecoveryReport>> get groupedExternalReports {
    final result = {
      for (final b in DistanceBracket.values) b: <RecoveryReport>[],
    };
    for (final report in externalReports) {
      final bracket = DistanceBracket.fromKm(_distanceToKmReturn);
      result[bracket]!.add(report);
    }
    return result;
  }

  @override
  Map<DistanceBracket, int> get unreadPerBracket {
    final result = {for (final b in DistanceBracket.values) b: 0};
    for (final report in externalReports) {
      if (!report.isRead) {
        final bracket = DistanceBracket.fromKm(_distanceToKmReturn);
        result[bracket] = result[bracket]! + 1;
      }
    }
    return result;
  }

  double? _navigatorProgress;
  String? _navigatorDistanceRemaining;

  @override
  double? navigatorProgress(RecoveryReport report) => _navigatorProgress;

  @override
  String? navigatorDistanceRemaining(RecoveryReport report) =>
      _navigatorDistanceRemaining;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNavigationViewModel extends ChangeNotifier
    implements NavigationViewModel {
  bool _hasLocation = false;

  @override
  LatLng? currentLocation;

  @override
  String activeRouteId = '';

  @override
  String? navigatingEntityId;

  @override
  RecoveryReport? navigatingReport;

  @override
  bool get isNavigating => navigatingEntityId != null;

  @override
  bool get hasLocation => _hasLocation;

  @override
  Future<void> refreshLocation() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeReportsViewModel fakeVm;
  late FakeNavigationViewModel fakeNavVm;

  final now = DateTime.utc(2026, 3, 24, 14, 30);

  int nextId = 1;

  RecoveryReport makeReport({
    String bumperNumber = 'HQ-42',
    String recoveryType = 'Wrecker',
    String fromCallsign = 'Ghost',
    String issue = 'flat tire',
    bool isOutgoing = false,
    bool isRead = false,
  }) {
    return RecoveryReport(
      id: nextId++,
      fromCallsign: fromCallsign,
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
      latitude: 33.0,
      longitude: -84.0,
      timestamp: now,
      isOutgoing: isOutgoing,
      isRead: isRead,
    );
  }

  setUp(() async {
    await getIt.reset();
    nextId = 1;
    fakeVm = FakeReportsViewModel();
    fakeNavVm = FakeNavigationViewModel();
    getIt.registerLazySingleton<ReportsViewModel>(() => fakeVm);
    getIt.registerLazySingleton<NavigationViewModel>(() => fakeNavVm);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createWidget() {
    return const MaterialApp(
      home: Scaffold(body: ReportsPage()),
    );
  }

  testWidgets('shows empty state when no reports', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.text('No external reports yet'), findsOneWidget);
  });

  testWidgets('shows report list when reports exist', (tester) async {
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.text('No external reports yet'), findsNothing);
    expect(find.text('HQ-42 — Wrecker'), findsOneWidget);
  });

  testWidgets('shows Tow Bar icon for Tow Bar type', (tester) async {
    fakeVm.reports.add(makeReport(recoveryType: 'Tow Bar'));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.change_history), findsOneWidget);
  });

  testWidgets('shows shipping icon for Wrecker type', (tester) async {
    fakeVm.reports.add(makeReport(recoveryType: 'Wrecker'));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
  });

  testWidgets('shows "From callsign" for incoming report', (tester) async {
    fakeVm.reports.add(makeReport(fromCallsign: 'Alpha'));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.textContaining('From Alpha'), findsOneWidget);
  });

  testWidgets('shows "Sent" for outgoing report', (tester) async {
    fakeVm.reports.add(makeReport(isOutgoing: true));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your Reports'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sent'), findsOneWidget);
  });

  testWidgets('read reports have normal subtitle', (tester) async {
    fakeVm.reports.add(makeReport(isRead: true));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    final subtitle = tester.widget<Text>(find.textContaining('From Ghost'));
    expect(subtitle.style?.fontWeight, FontWeight.normal);
  });

  testWidgets('Nav button hidden when no location', (tester) async {
    fakeNavVm._hasLocation = false;
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.navigation), findsNothing);
  });

  testWidgets('Nav button visible when location available', (tester) async {
    fakeNavVm._hasLocation = true;
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.navigation_outlined), findsOneWidget);
  });

  testWidgets('Nav button hidden on outgoing report even with location',
      (tester) async {
    fakeNavVm._hasLocation = true;
    fakeVm.reports.add(makeReport(isOutgoing: true));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your Reports'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.navigation_outlined), findsNothing);
    expect(find.byIcon(Icons.navigation), findsNothing);
  });

  testWidgets('detail sheet shows Navigate button for external report',
      (tester) async {
    fakeNavVm._hasLocation = true;
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Navigate'), findsOneWidget);
  });

  testWidgets('detail sheet hides Navigate button for outgoing report',
      (tester) async {
    fakeNavVm._hasLocation = true;
    fakeVm.reports.add(makeReport(isOutgoing: true));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your Reports'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Navigate'), findsNothing);
  });

  testWidgets('tapping View opens detail bottom sheet', (tester) async {
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(find.text('Issue'), findsOneWidget);
    expect(find.text('flat tire'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
  });

  testWidgets('detail sheet shows From for incoming report', (tester) async {
    fakeVm.reports.add(makeReport(fromCallsign: 'Bravo'));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(find.text('From'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets(
      'detail sheet shows Direction for outgoing report', (tester) async {
    fakeVm.reports.add(makeReport(isOutgoing: true));
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your Reports'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(find.text('Direction'), findsOneWidget);
    expect(find.text('Sent by you'), findsOneWidget);
  });

  testWidgets('tapping View marks report as read', (tester) async {
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('HQ-42 — Wrecker'));
    await tester.pumpAndSettle();

    expect(fakeVm.markedAsRead.length, 1);
  });

  testWidgets('multiple reports render in accordion', (tester) async {
    fakeVm.reports.add(makeReport(bumperNumber: 'A-01'));
    fakeVm.reports.add(makeReport(bumperNumber: 'B-02'));
    fakeVm.reports.add(makeReport(bumperNumber: 'C-03'));

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('A-01 — Wrecker'), findsOneWidget);
    expect(find.text('B-02 — Wrecker'), findsOneWidget);
    expect(find.text('C-03 — Wrecker'), findsOneWidget);
  });

  testWidgets('distance shown in subtitle when available', (tester) async {
    fakeVm._distanceReturn = '5.23 km';
    fakeVm.reports.add(makeReport());
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('5.23 km'), findsOneWidget);
  });

  group('gestures', () {
    testWidgets('show the delete icon when sliding to the left',
            (tester) async {
          fakeVm.reports.add(makeReport());
          await tester.pumpWidget(createWidget());
          await tester.pumpAndSettle();

          await tester.drag(find.byType(Dismissible), const Offset(-200, 0));
          await tester.pump();

          expect(find.byIcon(Icons.delete), findsOneWidget);
        });

    testWidgets('deletes report when slid fully to the left', (tester) async {
      final report = makeReport();
      fakeVm.reports.add(report);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(fakeVm.deletedReports.contains(report), isTrue);
      expect(find.text('HQ-42 — Wrecker'), findsNothing);
    });
  });

  group('progress bar', () {
    testWidgets('shows progress bar on outgoing report with navigator',
        (tester) async {
      fakeVm._navigatorProgress = 0.6;
      fakeVm._navigatorDistanceRemaining = '5.0 km away';
      fakeVm.reports.add(makeReport(isOutgoing: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your Reports'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Responder en route'), findsOneWidget);
      expect(find.textContaining('5.0 km away'), findsOneWidget);
    });

    testWidgets('no progress bar when navigator progress is null',
        (tester) async {
      fakeVm._navigatorProgress = null;
      fakeVm.reports.add(makeReport(isOutgoing: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your Reports'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('no progress bar on external reports even with navigator',
        (tester) async {
      fakeVm._navigatorProgress = 0.5;
      fakeVm._navigatorDistanceRemaining = '3.0 km away';
      fakeVm.reports.add(makeReport(isOutgoing: false));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('distance accordion', () {
    testWidgets('shows accordion with bracket label and count', (tester) async {
      fakeVm._distanceToKmReturn = 3.5;
      fakeVm.reports.add(makeReport(bumperNumber: 'A-01'));
      fakeVm.reports.add(makeReport(bumperNumber: 'B-02'));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('2 - 5 km (2)'), findsOneWidget);
    });

    testWidgets('shows unread badge on accordion', (tester) async {
      fakeVm._distanceToKmReturn = 0.5;
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('no unread badge when all reports read', (tester) async {
      fakeVm._distanceToKmReturn = 0.5;
      fakeVm.reports.add(makeReport(isRead: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('only shows non-empty accordions', (tester) async {
      fakeVm._distanceToKmReturn = 15.0;
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('10 - 20 km (1)'), findsOneWidget);
    });

    testWidgets('accordion auto-expands when it has unread reports',
        (tester) async {
      fakeVm._distanceToKmReturn = 7.0;
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('HQ-42 — Wrecker'), findsOneWidget);
    });

    testWidgets('accordion collapsed when all reports read', (tester) async {
      fakeVm._distanceToKmReturn = 7.0;
      fakeVm.reports.add(makeReport(isRead: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('HQ-42 — Wrecker'), findsNothing);
      expect(find.text('5 - 10 km (1)'), findsOneWidget);
    });

    testWidgets('uses unknown bracket when distance is null', (tester) async {
      fakeVm._distanceToKmReturn = null;
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Unknown distance'), findsOneWidget);
    });

    testWidgets('unread card has purple highlight', (tester) async {
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('read card has no purple highlight', (tester) async {
      fakeVm.reports.add(makeReport(isRead: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull);
    });

    testWidgets('mark all read button shown when unread reports exist',
        (tester) async {
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('mark all read button hidden when all read', (tester) async {
      fakeVm.reports.add(makeReport(isRead: true));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('tapping mark all read calls markBracketAsRead',
        (tester) async {
      fakeVm._distanceToKmReturn = 3.0;
      fakeVm.reports.add(makeReport());
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.done_all));
      await tester.pumpAndSettle();

      expect(fakeVm.bracketMarkedAsRead.length, 1);
      expect(fakeVm.bracketMarkedAsRead.first, DistanceBracket.from2to5km);
    });
  });
}
