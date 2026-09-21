import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';
import 'package:ivy_pulse/presentation/reports/reports_page.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReportsViewModel viewModel;

  setUp(() async {
    await getIt.reset();
    viewModel = FakeReportsViewModel();
    getIt.registerLazySingleton<ReportsViewModel>(() => viewModel);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: ReportsPage()),
      );

  Future<void> openTab(WidgetTester tester, ReportsTab tab) async {
    await tester.tap(find.text(tab.label));
    await tester.pumpAndSettle();
  }

  group('report cards', () {
    testWidgets('a card names the vehicle, the crew and its fault tally',
        (tester) async {
      viewModel.reports.add(buildReport(
        id: 1,
        entityId: 'mine-1',
        bumperNumber: 'A-11',
        vehicleType: VehicleType.stryker,
        isOutgoing: true,
        faults: [
          buildFault(severity: FaultSeverity.redX),
          buildFault(severity: FaultSeverity.dash),
        ],
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.textContaining('SGT SMITH'), findsOneWidget);
      expect(find.byType(FaultTallyBar), findsOneWidget);
      expect(find.text('2 FAULTS'), findsOneWidget);
      expect(find.text('RED X: 1'), findsOneWidget);
      expect(find.text('DASH: 1'), findsOneWidget);
    });

    testWidgets('a clean vehicle says so instead of showing an empty tally',
        (tester) async {
      viewModel.reports.add(
        buildReport(id: 1, entityId: 'mine-1', isOutgoing: true),
      );

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('No faults — fully serviceable'), findsOneWidget);
      expect(find.byType(SeverityBadge), findsNothing);
    });

    testWidgets('a device that has sent nothing says so', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(
        find.text('No PMCS submitted from this device yet'),
        findsOneWidget,
      );
    });

    testWidgets('a long fault list is collapsed until the card is tapped',
        (tester) async {
      viewModel.reports.add(buildReport(
        id: 1,
        entityId: 'mine-1',
        isOutgoing: true,
        faults: [
          for (var i = 0; i < 5; i++)
            buildFault(itemId: 'B-ENG-0$i', severity: FaultSeverity.dash),
        ],
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('+2 more — tap to expand'), findsOneWidget);

      await tester.tap(find.text('A-11 - Stryker'));
      await tester.pumpAndSettle();

      expect(find.text('+2 more — tap to expand'), findsNothing);
      expect(find.textContaining('B-ENG-04'), findsOneWidget);
    });

    testWidgets('opening a card marks it read so the badge can clear',
        (tester) async {
      final report = buildReport(
        id: 2,
        entityId: 'bravo-1',
        isOutgoing: false,
        isRead: false,
      );
      viewModel.reports.add(report);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.unit);

      await tester.tap(find.text('A-11 - Stryker'));
      await tester.pumpAndSettle();

      expect(viewModel.markedRead, [report]);
    });
  });

  group('queued submissions banner', () {
    testWidgets('a parked submission is surfaced so nobody assumes it sent',
        (tester) async {
      viewModel.queuedCount.value = 2;

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(
        find.text('2 submissions queued — will send on reconnect'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('a single parked submission is not pluralised', (tester) async {
      viewModel.queuedCount.value = 1;

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(
        find.text('1 submission queued — will send on reconnect'),
        findsOneWidget,
      );
    });

    testWidgets('an empty queue shows no banner', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.textContaining('queued'), findsNothing);
    });

    testWidgets('the banner appears as soon as the queue parks something',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off), findsNothing);

      viewModel.queuedCount.value = 3;
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });

  group('the three tabs', () {
    testWidgets('it opens on your own PMCS and keeps other crews off it',
        (tester) async {
      viewModel.myUic = 'WJ8TAA';
      viewModel.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'mine',
          bumperNumber: 'A-11',
          isOutgoing: true,
        ),
        buildReport(
          id: 2,
          entityId: 'theirs',
          bumperNumber: 'B-22',
          isOutgoing: false,
          uic: 'WJ8TAA',
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(find.text('B-22 - Stryker'), findsNothing);
    });

    testWidgets('a vehicle walked twice gets one header and both PMCS',
        (tester) async {
      viewModel.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'first',
          bumperNumber: 'A-11',
          isOutgoing: true,
          timestamp: DateTime.utc(2026, 3, 24, 6),
        ),
        buildReport(
          id: 2,
          entityId: 'second',
          bumperNumber: 'A-11',
          isOutgoing: true,
          timestamp: DateTime.utc(2026, 3, 24, 9),
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('A-11'), findsOneWidget);
      expect(find.text('2 PMCS'), findsOneWidget);
      expect(find.text('A-11 - Stryker'), findsNWidgets(2));
    });

    testWidgets('bumper numbers are listed in order so a vehicle can be '
        'run down', (tester) async {
      viewModel.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'c',
          bumperNumber: 'C-33',
          isOutgoing: true,
        ),
        buildReport(
          id: 2,
          entityId: 'a',
          bumperNumber: 'A-11',
          isOutgoing: true,
        ),
        buildReport(
          id: 3,
          entityId: 'b',
          bumperNumber: 'B-22',
          isOutgoing: true,
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      final headers = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((text) => text == 'A-11' || text == 'B-22' || text == 'C-33')
          .toList();
      expect(headers, ['A-11', 'B-22', 'C-33']);
    });

    testWidgets('my unit holds the crews signed for under the same UIC',
        (tester) async {
      viewModel.myUic = 'WJ8TAA';
      viewModel.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'mine',
          bumperNumber: 'A-11',
          isOutgoing: true,
        ),
        buildReport(
          id: 2,
          entityId: 'peer',
          bumperNumber: 'B-22',
          isOutgoing: false,
          uic: 'WJ8TAA',
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.unit);

      expect(find.text('B-22 - Stryker'), findsOneWidget);
      expect(find.text('A-11 - Stryker'), findsNothing);
      expect(find.text('OTHER UNITS'), findsNothing);
    });

    testWidgets('a PMCS from another unit is set apart, not dropped',
        (tester) async {
      viewModel.myUic = 'WJ8TAA';
      viewModel.reports.addAll([
        buildReport(
          id: 1,
          entityId: 'peer',
          bumperNumber: 'B-22',
          isOutgoing: false,
          uic: 'WJ8TAA',
        ),
        buildReport(
          id: 2,
          entityId: 'attached',
          bumperNumber: 'Z-99',
          isOutgoing: false,
          uic: 'WAB4C0',
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.unit);

      expect(find.text('B-22 - Stryker'), findsOneWidget);
      expect(find.text('OTHER UNITS'), findsOneWidget);
      expect(find.text('Z-99 - Stryker'), findsOneWidget);
    });

    testWidgets('with no UIC of our own nothing is filtered away',
        (tester) async {
      viewModel.myUic = '';
      viewModel.reports.add(buildReport(
        id: 1,
        entityId: 'peer',
        bumperNumber: 'B-22',
        isOutgoing: false,
        uic: 'WAB4C0',
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.unit);

      expect(find.text('B-22 - Stryker'), findsOneWidget);
      expect(find.text('OTHER UNITS'), findsNothing);
    });

    testWidgets('an empty tab says which one is empty', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(
        find.text('No PMCS submitted from this device yet'),
        findsOneWidget,
      );

      await openTab(tester, ReportsTab.unit);
      expect(
        find.text('No PMCS from other crews in your unit yet'),
        findsOneWidget,
      );

      await openTab(tester, ReportsTab.queued);
      expect(
        find.text('Nothing waiting — every PMCS has been sent'),
        findsOneWidget,
      );
    });
  });

  group('the queued tab', () {
    testWidgets('a parked submission names the vehicle and what it waits on',
        (tester) async {
      viewModel.queued.add(buildQueuedSubmission(
        id: 1,
        bumperNumber: 'A-11',
        faultCount: 2,
        redXCount: 1,
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.queued);

      expect(find.text('A-11 - Stryker'), findsOneWidget);
      expect(
        find.textContaining('2 fault(s), 1 RED X'),
        findsOneWidget,
      );
      expect(find.textContaining('waiting on lattice'), findsOneWidget);
    });

    testWidgets('the last one parked is the one on top', (tester) async {
      viewModel.queued.addAll([
        buildQueuedSubmission(
          id: 1,
          entityId: 'older',
          bumperNumber: 'A-11',
          createdAt: DateTime.utc(2026, 3, 24, 6),
        ),
        buildQueuedSubmission(
          id: 2,
          entityId: 'newest',
          bumperNumber: 'Z-99',
          createdAt: DateTime.utc(2026, 3, 24, 9),
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.queued);

      final headers = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((text) => text == 'A-11' || text == 'Z-99')
          .toList();
      // Last in, first out — Z-99 parked later, so it leads despite sorting
      // after A-11 alphabetically.
      expect(headers, ['Z-99', 'A-11']);
    });

    testWidgets('one vehicle parked twice keeps both under its header',
        (tester) async {
      viewModel.queued.addAll([
        buildQueuedSubmission(
          id: 1,
          entityId: 'first',
          bumperNumber: 'A-11',
          createdAt: DateTime.utc(2026, 3, 24, 6),
        ),
        buildQueuedSubmission(
          id: 2,
          entityId: 'second',
          bumperNumber: 'A-11',
          createdAt: DateTime.utc(2026, 3, 24, 9),
        ),
      ]);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.queued);

      expect(find.text('A-11'), findsOneWidget);
      expect(find.text('2 PMCS'), findsOneWidget);
      expect(find.text('A-11 - Stryker'), findsNWidgets(2));
    });
  });

  group('withdrawing a report', () {
    testWidgets('deleting is gated behind a confirmation', (tester) async {
      final report = buildReport(
        id: 1,
        entityId: 'mine-1',
        isOutgoing: true,
      );
      viewModel.reports.add(report);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete PMCS?'), findsOneWidget);
      expect(
        find.text(
          'A-11 - Stryker will be withdrawn from Lattice and the mesh.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(viewModel.deleted, isEmpty);
      expect(find.text('A-11 - Stryker'), findsOneWidget);
    });

    testWidgets('confirming withdraws the report', (tester) async {
      final report = buildReport(
        id: 1,
        entityId: 'mine-1',
        isOutgoing: true,
      );
      viewModel.reports.add(report);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(viewModel.deleted, [report]);
      expect(find.text('A-11 - Stryker'), findsNothing);
    });

    testWidgets("a received report is only dropped from this device",
        (tester) async {
      viewModel.reports.add(buildReport(
        id: 1,
        entityId: 'bravo-1',
        isOutgoing: false,
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await openTab(tester, ReportsTab.unit);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.text('A-11 - Stryker will be removed from this device only.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('the map button hands the report to the view model',
      (tester) async {
    final report = buildReport(id: 1, entityId: 'mine-1', isOutgoing: true);
    viewModel.reports.add(report);

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.place_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.viewed, [report]);
  });

  group('who signed it', () {
    testWidgets('a verified report carries no warning', (tester) async {
      viewModel.reports.add(buildReport(signature: buildSignature()));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gpp_maybe_outlined), findsNothing);
    });

    testWidgets('an unverified report is flagged next to the name',
        (tester) async {
      // The maintainer decides how much to trust a PMCS by who signed it, so
      // "nobody checked" sits on the card, not two screens deeper.
      viewModel.reports.add(buildReport(
        operator: 'UNVERIFIED',
        signature: buildUnverifiedSignature(),
      ));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gpp_maybe_outlined), findsOneWidget);
      expect(find.textContaining('UNVERIFIED'), findsOneWidget);
    });

    testWidgets('a report from a build that predates verification is flagged',
        (tester) async {
      viewModel.reports.add(buildReport());

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gpp_maybe_outlined), findsOneWidget);
    });
  });
}
