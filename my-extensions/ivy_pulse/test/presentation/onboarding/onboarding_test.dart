import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/domain/repositories/profile_repo.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/onboarding/onboarding_gate.dart';
import 'package:ivy_pulse/presentation/onboarding/onboarding_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';

import '../../support/fakes.dart';

/// Stands in for the app shell so the gate can be tested without the whole
/// dependency graph behind HomePage.
const shellMarker = Key('shell');

class ExplodingProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getProfile() async => throw StateError('store is down');

  @override
  Future<void> saveProfile(Profile profile) async =>
      throw StateError('store is down');
}

void main() {
  late FakeProfileRepository repository;

  void register(ProfileRepository repo) {
    getIt.registerLazySingleton<ProfileRepository>(() => repo);
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(getIt<ProfileRepository>()),
    );
  }

  setUp(() async {
    await getIt.reset();
    repository = FakeProfileRepository();
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget subject() => MaterialApp(
        theme: appTheme,
        home: const OnboardingGate(
          child: SizedBox(key: shellMarker),
        ),
      );

  Finder uicField() => find.widgetWithText(CustomTextField, 'UIC');
  Finder continueButton() => find.widgetWithText(CustomButton, 'CONTINUE');

  group('who gets asked', () {
    testWidgets('a device with nothing stored is asked for a UIC',
        (tester) async {
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byKey(shellMarker), findsNothing);
      expect(uicField(), findsOneWidget);
    });

    testWidgets('a device that already has a UIC goes straight to the app',
        (tester) async {
      repository.profile = const Profile(uic: 'WJ8TAA');
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byKey(shellMarker), findsOneWidget);
    });

    testWidgets('a stored profile with a blank UIC is treated as unset',
        (tester) async {
      repository.profile = const Profile(uic: '   ');
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('a store that cannot be read lets the operator through '
        'rather than stranding them on a screen that cannot save',
        (tester) async {
      register(ExplodingProfileRepository());

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byKey(shellMarker), findsOneWidget);
    });
  });

  group('answering it', () {
    testWidgets('the UIC is stored upper case and the app opens',
        (tester) async {
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'wj8taa');
      await tester.pumpAndSettle();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(repository.saved.single.uic, 'WJ8TAA');
      expect(find.byKey(shellMarker), findsOneWidget);
    });

    testWidgets('CONTINUE stays dead until something is typed', (tester) async {
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      final button = tester.widget<CustomButton>(continueButton());
      expect(button.onPressed, isNull);

      await tester.enterText(uicField(), 'W12ABC');
      await tester.pumpAndSettle();

      expect(
        tester.widget<CustomButton>(continueButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('whitespace alone is refused and the operator stays put',
        (tester) async {
      register(repository);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), '   ');
      await tester.pumpAndSettle();

      expect(tester.widget<CustomButton>(continueButton()).onPressed, isNull);
      expect(repository.saved, isEmpty);
      expect(find.byKey(shellMarker), findsNothing);
    });

    testWidgets('a save that fails keeps the operator on the question',
        (tester) async {
      register(ExplodingProfileRepository());
      // Read failure would skip onboarding, so drive the page directly to
      // exercise the save path on a store that refuses writes.
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: OnboardingPage(onComplete: () {}),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(uicField(), 'WJ8TAA');
      await tester.pumpAndSettle();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(find.text('Could not save the UIC — try again'), findsOneWidget);
      expect(find.byType(OnboardingPage), findsOneWidget);
    });
  });
}
