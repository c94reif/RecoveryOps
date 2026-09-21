import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/profile/profile_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';

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

  Finder uicField() => find.widgetWithText(CustomTextField, 'UIC');

  Future<void> tapSave(WidgetTester tester, String label) async {
    final save = find.widgetWithText(CustomButton, label);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
  }

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
      // latched and showed Save Edit on work the operator never did.
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

      expect(find.widgetWithText(CustomButton, 'Save'), findsOneWidget);
    });

    testWidgets('reads Save Edit when a profile already exists',
        (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'WAB4C0');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CustomButton, 'Save Edit'), findsOneWidget);
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
    testWidgets('a typed UIC reaches the database upper case', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'wab4c0');
      await tester.pumpAndSettle();

      await tapSave(tester, 'Save');
      await tester.pumpAndSettle();

      expect(repository.saved.single.uic, 'WAB4C0');
      expect(find.byType(CustomButton), findsNothing);
    });

    testWidgets('clearing a stored UIC is refused and says why',
        (tester) async {
      // Blanking the field on a device that has a UIC is the only way to
      // reach the empty save — on a fresh device an empty field is not an
      // edit, so there is no button to press.
      repository.profile = const Profile(uic: 'WJ8TAA');

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), '   ');
      await tester.pumpAndSettle();

      await tapSave(tester, 'Save Edit');
      await tester.pump();

      expect(find.text('UIC is required'), findsOneWidget);
      expect(repository.saved, isEmpty);
      expect(repository.profile!.uic, 'WJ8TAA');
    });
  });
}
