import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/profile/profile_page.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeProfileRepository repository;
  late int refreshed;
  Completer<void>? savedGate;

  setUp(() async {
    await getIt.reset();
    repository = FakeProfileRepository(const Profile(
      uic: 'WJ8TAA',
      unitName: 'Headquarters',
      followedUnits: [FollowedUnit(uic: 'WAB4C0', name: 'Alpha')],
    ));
    refreshed = 0;
    savedGate = null;
    getIt.registerFactory<ProfileViewModel>(
        () => ProfileViewModel(repository, onSaved: (_) async {
              refreshed++;
              await savedGate?.future;
            }));
  });

  tearDown(() => getIt.reset());

  Widget subject({double textScale = 1}) => MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: ProfilePage()),
      );

  Finder field(String label) => find.widgetWithText(CustomTextField, label);

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('names and followed units survive page recreation',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(
        tester
            .state<ProfilePageState>(find.byType(ProfilePage))
            .unitNameController
            .text,
        'Headquarters');
    await tap(tester, find.text('Follow another UIC'));
    await tester.enterText(field('UIC to follow'), 'w12abc');
    await tester.enterText(field('Unit name (optional)'), 'Bravo Company');
    await tap(tester, find.text('Save unit'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Headquarters');
    expect(repository.profile!.followedUnits.map((unit) => unit.uic),
        ['WAB4C0', 'W12ABC']);
    expect(refreshed, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bravo Company'));
    expect(find.byTooltip('Manage W12ABC'), findsOneWidget);
    expect(find.text('Bravo Company'), findsOneWidget);
  });

  testWidgets('followed unit editor renames, changes UIC, and removes a unit',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Manage WAB4C0'));
    await tap(tester, find.text('Edit unit'));
    expect(find.text('Edit followed unit'), findsOneWidget);
    await tester.enterText(field('UIC to follow'), 'WAB4C1');
    await tester.enterText(field('Unit name (optional)'), 'Alpha Company');
    await tap(tester, find.text('Save unit'));

    expect(repository.profile!.followedUnits.single.label,
        'Alpha Company (WAB4C1)');
    await tap(tester, find.byTooltip('Manage WAB4C1'));
    await tap(tester, find.text('Remove unit'));
    expect(repository.profile!.followedUnits, isEmpty);
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Headquarters');
    expect(refreshed, 2);
  });

  testWidgets('duplicates and malformed UICs keep the editor open',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, find.text('Follow another UIC'));
    for (final (uic, message) in [
      ('W12', 'UIC must be exactly 6 characters'),
      ('wj8taa', 'This is already your default UIC.'),
      ('wab4c0', 'You already follow this UIC.'),
    ]) {
      await tester.enterText(field('UIC to follow'), uic);
      await tap(tester, find.text('Save unit'));
      expect(find.text(message), findsWidgets);
      expect(find.byType(AlertDialog), findsOneWidget);
    }
    expect(repository.saved, isEmpty);
    await tap(tester, find.text('Cancel'));
  });

  testWidgets('saving only a primary local name retains all subscribed UICs',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(
        field('Default unit name (optional)'), 'Battalion HQ');
    await tap(tester, find.text('Save default UIC'));

    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Battalion HQ');
    expect(repository.profile!.followedUnits.single.uic, 'WAB4C0');
    expect(refreshed, 1);
  });

  testWidgets('followed-unit changes preserve an unsaved primary UIC draft',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(field('Default UIC'), 'W12ABC');
    await tester.enterText(field('Default unit name (optional)'), 'Draft name');
    await tap(tester, find.text('Follow another UIC'));
    await tester.enterText(field('UIC to follow'), 'W12ABD');
    await tap(tester, find.text('Save unit'));

    final state = tester.state<ProfilePageState>(find.byType(ProfilePage));
    expect(state.uicController.text, 'W12ABC');
    expect(state.unitNameController.text, 'Draft name');
    expect(state.viewModel.isDirty, isTrue);
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Headquarters');
  });

  testWidgets('unit editor works on a narrow phone with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(subject(textScale: 1.8));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Follow another UIC'));
    await tester.enterText(field('UIC to follow'), 'W12ABC');
    await tester.ensureVisible(field('Unit name (optional)'));
    await tester.enterText(field('Unit name (optional)'),
        'A very long local unit name that must wrap on a phone');
    await tap(tester, find.text('Save unit'));

    expect(repository.profile!.followedUnits, hasLength(2));
    await tester.ensureVisible(find.byTooltip('Manage W12ABC'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage W12ABC').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending save blocks taps and preserves newer accessibility edits',
      (tester) async {
    savedGate = Completer<void>();
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(
        field('Default unit name (optional)'), 'Battalion HQ');
    await tap(tester, find.text('Save default UIC'));

    final state = tester.state<ProfilePageState>(find.byType(ProfilePage));
    expect(state.viewModel.isSaving, isTrue);
    for (final label in ['Default UIC', 'Default unit name (optional)']) {
      final blockers = tester.widgetList<AbsorbPointer>(find.ancestor(
          of: field(label), matching: find.byType(AbsorbPointer)));
      expect(blockers.any((blocker) => blocker.absorbing), isTrue);
    }
    await tester.ensureVisible(field('Default UIC'));
    await tester.tap(field('Default UIC'), warnIfMissed: false);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);

    // Changes delivered outside pointer input must survive the completion too.
    state.uicController.text = 'W12ABC';
    state.unitNameController.text = 'Newer draft';

    savedGate!.complete();
    await tester.pumpAndSettle();
    expect(state.viewModel.isSaving, isFalse);
    expect(state.uicController.text, 'W12ABC');
    expect(state.unitNameController.text, 'Newer draft');
    expect(state.viewModel.isDirty, isTrue);
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Battalion HQ');
    expect(repository.saved, hasLength(1));
  });
}
