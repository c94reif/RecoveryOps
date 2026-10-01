import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/injection.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/repositories/profile_repo.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/maintainer/maintainer_page.dart';
import 'package:circle_x/presentation/profile/profile_page.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';
import 'package:circle_x/presentation/reports/reports_view_model.dart';

import '../../support/fakes.dart';

void main() {
  late FakeProfileRepository repository;

  setUp(() async {
    await getIt.reset();
    repository = FakeProfileRepository();
    getIt.registerLazySingleton<ProfileRepository>(() => repository);
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(getIt<ProfileRepository>()),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: ProfilePage()),
      );

  ProfilePageState stateOf(WidgetTester tester) =>
      tester.state<ProfilePageState>(find.byType(ProfilePage));

  Finder uicField() => find.widgetWithText(CustomTextField, 'Default UIC');

  Future<void> tapSave(WidgetTester tester, String label) async {
    final save = find.widgetWithText(CustomButton, label);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
  }

  testWidgets('maintainer mode returns to the unsaved profile edit',
      (tester) async {
    final reports = FakeReportsViewModel();
    getIt.registerSingleton<ReportsViewModel>(reports);
    repository.profile = const Profile(uic: 'WJ8TAA');
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.enterText(uicField(), 'WAB4C0');
    await tester.pumpAndSettle();

    expect(find.text('Enter full screen'), findsNothing);
    expect(find.text('Exit full screen'), findsNothing);
    final enter = find.text('Enter maintainer mode');
    await tester.ensureVisible(enter);
    await tester.tap(enter);
    await tester.pumpAndSettle();

    expect(find.byType(MaintainerPage), findsOneWidget);
    expect(find.text('Maintainer mode'), findsOneWidget);
    expect(reports.syncCalls, 1);
    await tester.tap(find.byTooltip('Exit maintainer mode'));
    await tester.pumpAndSettle();

    expect(find.byType(MaintainerPage), findsNothing);
    expect(stateOf(tester).uicController.text, 'WAB4C0');
    expect(
        find.widgetWithText(CustomButton, 'Save default UIC'), findsOneWidget);
    expect(repository.saved, isEmpty);

    await tester.ensureVisible(find.text('Enter maintainer mode'));
    await tester.tap(find.text('Enter maintainer mode'));
    await tester.pumpAndSettle();
    expect(reports.syncCalls, 2);
  });

  group('what the profile holds', () {
    testWidgets('a stored UIC fills the one field there is', (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('WJ8TAA'), findsOneWidget);
      expect(uicField(), findsOneWidget);
    });

    testWidgets('an empty device starts with nothing filled in',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(stateOf(tester).uicController.text, '');
      expect(uicField(), findsOneWidget);
    });

    testWidgets('there is no name and no rank to fill in any more',
        (tester) async {
      // The operator's name and rank come off their CAC at sign-off now, so a
      // stale one typed here could never disagree with the 5988-E.
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(CustomTextField), findsOneWidget);
      expect(find.widgetWithText(CustomTextField, 'Name'), findsNothing);
      expect(find.text('RANK'), findsNothing);
    });
  });

  group('the save button', () {
    testWidgets('stays hidden on a device with nothing saved and nothing typed',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(CustomButton), findsNothing);
    });

    testWidgets('stays hidden on a freshly loaded profile', (tester) async {
      // Regression from the name/rank/unit profile: the controllers were
      // filled before the picked field was restored, so the dirty check
      // latched and showed a save button on work the operator never did.
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(CustomButton), findsNothing);
    });

    testWidgets('appears once the UIC is edited', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'WJ8TAA');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CustomButton, 'Save default UIC'),
          findsOneWidget);
    });

    testWidgets('names the default UIC when updating a saved profile',
        (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'WAB4C0');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CustomButton, 'Save default UIC'),
          findsOneWidget);
    });

    testWidgets('goes away again when the edit is reverted', (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'WAB4C0');
      await tester.pumpAndSettle();
      expect(find.byType(CustomButton), findsOneWidget);

      await tester.enterText(uicField(), 'WJ8TAA');
      await tester.pumpAndSettle();

      expect(find.byType(CustomButton), findsNothing);
    });
  });

  group('saving', () {
    testWidgets(
        'can edit and save in a narrow panel with large text and keyboard',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const Scaffold(
          resizeToAvoidBottomInset: false,
          body: ProfilePage(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(uicField());
      await tester.enterText(uicField(), 'WAB4C0');
      await tester.pumpAndSettle();
      await tapSave(tester, 'Save default UIC');
      await tester.pumpAndSettle();

      expect(repository.saved.single.uic, 'WAB4C0');
      expect(find.text('Default UIC saved'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final maintainerButton = find.text('Enter maintainer mode');
      await tester.ensureVisible(maintainerButton);
      await tester.pumpAndSettle();
      expect(maintainerButton.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a typed UIC reaches the database upper case', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'wab4c0');
      await tester.pumpAndSettle();

      await tapSave(tester, 'Save default UIC');
      await tester.pumpAndSettle();

      expect(repository.saved.single.uic, 'WAB4C0');
      expect(find.byType(CustomButton), findsNothing);
    });

    testWidgets('clearing a stored UIC is refused and says why',
        (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), '   ');
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<CustomButton>(
                  find.widgetWithText(CustomButton, 'Save default UIC'))
              .onPressed,
          isNull);
      expect(find.text('UIC is required'), findsOneWidget);
      expect(repository.saved, isEmpty);
      expect(repository.profile!.uic, 'WJ8TAA');
    });

    testWidgets('invalid lengths disable saving until the UIC is corrected',
        (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      for (final value in ['W12', 'W12ABCD', 'W12A!C']) {
        await tester.enterText(uicField(), value);
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<CustomButton>(
                    find.widgetWithText(CustomButton, 'Save default UIC'))
                .onPressed,
            isNull);
      }
      await tester.enterText(uicField(), 'W12ABC');
      await tester.pumpAndSettle();
      expect(find.text('6/6'), findsOneWidget);
      await tapSave(tester, 'Save default UIC');
      await tester.pumpAndSettle();
      expect(repository.saved.single.uic, 'W12ABC');
    });
  });
}
