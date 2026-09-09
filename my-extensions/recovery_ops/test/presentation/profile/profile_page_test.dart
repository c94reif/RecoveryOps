import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/repositories/profile_repo_impl.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_text_field.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_button.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';
import 'package:recovery_ops/presentation/profile/profile_page.dart';
import 'package:recovery_ops/core/di/injection.dart';

void main() {
  late AppDatabase db;
  late ProfileDao dao;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase.test(NativeDatabase.memory());
    dao = ProfileDao(db);
    getIt.registerLazySingleton<AppDatabase>(() => db);
    getIt.registerLazySingleton<ProfileDao>(() => dao);
    getIt.registerLazySingleton<ProfileRepository>(
      () => ProfileRepoImpl(dao),
    );
    getIt.registerFactory<ProfileViewModel>(
      () => ProfileViewModel(getIt<ProfileRepository>()),
    );
  });

  tearDown(() async {
    await db.close();
    await getIt.reset();
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: ProfilePage(),
      ),
    );
  }

  testWidgets('ProfilePage renders all three fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CustomTextField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(CustomTextField, 'Unit'), findsOneWidget);
  });

  testWidgets('Icons are displayed in text fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
  });

  testWidgets('Save button is hidden when no edits are made',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(CustomButton), findsNothing);
  });

  testWidgets('Save button appears when a field is edited',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John Doe');
    await tester.pump();

    expect(find.widgetWithText(CustomButton, 'Save'), findsOneWidget);
  });

  testWidgets('Save button shows "Save" for a new profile',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Unit'), 'Alpha');
    await tester.pump();

    expect(find.widgetWithText(CustomButton, 'Save'), findsOneWidget);
  });

  testWidgets('Saving a profile hides the save button',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Unit'), 'Alpha');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomButton), findsNothing);
  });

  testWidgets('Saving persists data to the database',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John Doe');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Unit'), 'Alpha 1');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Save'));
    await tester.pumpAndSettle();

    final profile = await dao.getProfile();
    expect(profile, isNotNull);
    expect(profile!.name, 'John Doe');
    expect(profile.unit, 'Alpha 1');
  });

  testWidgets('Shows snackbar after saving', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Unit'), 'Alpha');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Save'));
    await tester.pump();

    expect(find.text('Profile Saved!'), findsOneWidget);
  });

  testWidgets('Shows validation snackbar when fields are empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'John');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Save'));
    await tester.pump();

    expect(find.text('All fields are required'), findsOneWidget);
  });

  testWidgets('Loads existing profile on startup', (WidgetTester tester) async {
    await dao.saveProfile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.byType(CustomButton), findsNothing);
  });

  testWidgets('Save button shows "Save Edit" when editing existing profile',
      (WidgetTester tester) async {
    await dao.saveProfile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'Jane Updated');
    await tester.pump();

    expect(find.widgetWithText(CustomButton, 'Save Edit'), findsOneWidget);
  });

  testWidgets(
      'Editing an existing profile saves the updated payload to the database',
      (WidgetTester tester) async {
    await dao.saveProfile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'Jane Updated');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Unit'), 'Charlie 3');
    await tester.pump();

    await tester.tap(find.widgetWithText(CustomButton, 'Save Edit'));
    await tester.pumpAndSettle();

    final profile = await dao.getProfile();
    expect(profile, isNotNull);
    expect(profile!.name, 'Jane Updated');
    expect(profile.unit, 'Charlie 3');
  });

  testWidgets('Editing then reverting hides the save button',
      (WidgetTester tester) async {
    await dao.saveProfile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'Changed');
    await tester.pump();
    expect(find.byType(CustomButton), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Name'), 'Jane');
    await tester.pump();
    expect(find.byType(CustomButton), findsNothing);
  });
}
