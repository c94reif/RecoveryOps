import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/presentation/inspection/vehicle_manual_selector.dart';

void main() {
  final choices = <VehicleType>[];
  setUp(choices.clear);
  Widget subject({List<VehicleType> vehicles = VehicleType.values}) =>
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
            body: VehicleManualSelector(
                selected: VehicleType.stryker,
                vehicles: vehicles,
                onSelected: choices.add)),
      );
  final input = find.byKey(const ValueKey('vehicle-manual-search'));
  Finder option(VehicleType vehicle) =>
      find.byKey(ValueKey(('vehicle-manual-option', vehicle.wireName)));
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('vehicle-manual-selector')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'search finds a family, variant or unpunctuated TM and selects it',
      (tester) async {
    await tester.pumpWidget(subject());
    await open(tester);
    await tester.enterText(input, 'family');
    await tester.pumpAndSettle();
    expect(option(VehicleType.stryker), findsOneWidget);
    expect(option(VehicleType.jltv), findsOneWidget);
    await tester.enterText(input, '  jLtV  9232040010 ');
    await tester.pumpAndSettle();
    expect(option(VehicleType.stryker), findsNothing);
    expect(option(VehicleType.jltv), findsOneWidget);
    await tester.tap(option(VehicleType.jltv));
    await tester.pumpAndSettle();
    expect(choices, [VehicleType.jltv]);
  });

  testWidgets(
      'only registered checklists are offered and cancelling keeps selection',
      (tester) async {
    await tester.pumpWidget(subject(vehicles: [VehicleType.stryker]));
    await open(tester);
    await tester.enterText(input, 'jltv');
    await tester.pumpAndSettle();
    expect(find.text('No matching vehicles or manuals.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear vehicle search'));
    await tester.pumpAndSettle();
    expect(option(VehicleType.stryker), findsOneWidget);
    expect(option(VehicleType.jltv), findsNothing);
    await tester.tap(find.byTooltip('Close vehicle picker'));
    await tester.pumpAndSettle();
    expect(choices, isEmpty);
  });

  testWidgets('picker fits a narrow panel with large text and a keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(subject());
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.enterText(input, 'jltv');
    await tester.pumpAndSettle();
    await tester.ensureVisible(option(VehicleType.jltv));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(option(VehicleType.jltv));
    await tester.pumpAndSettle();
    expect(choices, [VehicleType.jltv]);
  });
}
