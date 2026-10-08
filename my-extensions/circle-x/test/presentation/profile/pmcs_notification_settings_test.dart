import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/services/pmcs_notification_port.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/profile/pmcs_notification_settings_card.dart';
import 'package:circle_x/presentation/profile/profile_page.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

import '../../support/fakes.dart';

class FakePhoneNotifications extends SilentPmcsNotificationPort {
  PmcsNotificationStatus status = const PmcsNotificationStatus(supported: true);
  final List<bool> enabledChoices = [];
  int statusReads = 0;
  int settingsOpens = 0;
  bool grantOnEnable = true;
  bool failRead = false;
  bool failSave = false;
  bool failSettings = false;
  Completer<PmcsNotificationStatus>? readGate;
  Completer<PmcsNotificationStatus>? saveGate;

  @override
  Future<PmcsNotificationStatus> getStatus() async {
    statusReads++;
    if (failRead) throw StateError('Read failed');
    return readGate?.future ?? status;
  }

  @override
  Future<PmcsNotificationStatus> setEnabled(bool enabled) async {
    enabledChoices.add(enabled);
    if (failSave) throw StateError('Save failed');
    if (saveGate != null) return saveGate!.future;
    status = PmcsNotificationStatus(
      supported: true,
      enabled: enabled,
      permissionGranted: enabled ? grantOnEnable : status.permissionGranted,
    );
    return status;
  }

  @override
  Future<void> openSettings() async {
    settingsOpens++;
    if (failSettings) throw StateError('Settings unavailable');
  }
}

void main() {
  late FakePhoneNotifications notifications;

  setUp(() async {
    notifications = FakePhoneNotifications();
    await getIt.reset();
  });
  tearDown(() => getIt.reset());

  Widget subject({double textScale = 1}) => MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PmcsNotificationSettingsCard(notifications: notifications),
          ),
        ),
      );

  Switch toggle(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('loading is disabled and reading never requests permission',
      (tester) async {
    notifications.readGate = Completer<PmcsNotificationStatus>();
    await tester.pumpWidget(subject());
    expect(toggle(tester).onChanged, isNull);
    expect(find.text('Loading notification settings…'), findsOneWidget);
    notifications.readGate!.complete(notifications.status);
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isFalse);
    expect(toggle(tester).onChanged, isNotNull);
    expect(notifications.enabledChoices, isEmpty);
  });

  testWidgets('only explicit toggles enable and disable silent notifications',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.textContaining('without sound or vibration'), findsOneWidget);
    expect(notifications.enabledChoices, isEmpty);
    await tap(tester, find.byType(Switch));
    expect(notifications.enabledChoices, [true]);
    expect(toggle(tester).value, isTrue);
    expect(find.text('Open notification settings'), findsNothing);
    await tap(tester, find.byType(Switch));
    expect(notifications.enabledChoices, [true, false]);
    expect(toggle(tester).value, isFalse);
  });

  testWidgets('denied permission keeps opt-in and offers phone settings',
      (tester) async {
    notifications.grantOnEnable = false;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, find.byType(Switch));
    expect(toggle(tester).value, isTrue);
    expect(
        find.text(
            'Allow notifications in your phone settings to receive them.'),
        findsOneWidget);
    await tap(tester, find.text('Open notification settings'));
    expect(notifications.settingsOpens, 1);
    expect(notifications.enabledChoices, [true]);

    notifications.status = const PmcsNotificationStatus(
        supported: true, enabled: true, permissionGranted: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Open notification settings'), findsNothing);
    expect(toggle(tester).value, isTrue);
    expect(notifications.enabledChoices, [true]);
  });

  testWidgets('unsupported version explains disabled phone notifications',
      (tester) async {
    notifications.status = const PmcsNotificationStatus();
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(toggle(tester).onChanged, isNull);
    expect(find.text('Phone notifications are unavailable in this version.'),
        findsOneWidget);
    await tap(tester, find.byType(Switch));
    expect(notifications.enabledChoices, isEmpty);
    expect(find.text('Open notification settings'), findsNothing);
  });

  testWidgets('failed loading can be retried without a permission request',
      (tester) async {
    notifications.failRead = true;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('Could not load notification settings. Try again.'),
        findsOneWidget);
    expect(toggle(tester).onChanged, isNull);
    notifications.failRead = false;
    await tap(tester, find.text('Try again'));
    expect(toggle(tester).onChanged, isNotNull);
    expect(notifications.enabledChoices, isEmpty);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('failed saving preserves displayed preference and can recover',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    notifications.failSave = true;
    await tap(tester, find.byType(Switch));
    expect(find.text('Could not update notification settings. Try again.'),
        findsOneWidget);
    expect(toggle(tester).value, isFalse);
    notifications.failSave = false;
    await tap(tester, find.text('Try again'));
    expect(notifications.enabledChoices, [true]);
    await tap(tester, find.byType(Switch));
    expect(toggle(tester).value, isTrue);
    expect(notifications.enabledChoices, [true, true]);
  });

  testWidgets('settings launch failures remain recoverable', (tester) async {
    notifications.status =
        const PmcsNotificationStatus(supported: true, enabled: true);
    notifications.failSettings = true;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tap(tester, find.text('Open notification settings'));
    expect(find.text('Could not open notification settings. Try again.'),
        findsOneWidget);
    notifications.failSettings = false;
    await tap(tester, find.text('Open notification settings'));
    expect(notifications.settingsOpens, 2);
    expect(find.text('Could not open notification settings. Try again.'),
        findsNothing);
    expect(notifications.enabledChoices, isEmpty);
  });

  testWidgets(
      'resume during permission request refreshes after saving completes',
      (tester) async {
    notifications.saveGate = Completer<PmcsNotificationStatus>();
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(toggle(tester).onChanged, isNull);
    expect(find.text('Saving notification preference…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(notifications.statusReads, 1);
    notifications.status = const PmcsNotificationStatus(
        supported: true, enabled: true, permissionGranted: true);
    notifications.saveGate!.complete(notifications.status);
    await tester.pumpAndSettle();
    expect(notifications.enabledChoices, [true]);
    expect(notifications.statusReads, 2);
    expect(toggle(tester).value, isTrue);
  });

  testWidgets(
      'late async completion after disposal does not update widget or listen to resumes',
      (tester) async {
    notifications.readGate = Completer<PmcsNotificationStatus>();
    await tester.pumpWidget(subject());
    await tester.pumpWidget(const SizedBox());
    notifications.readGate!
        .completeError(StateError('Read failed after closing'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(notifications.statusReads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale status from a replaced notification port is ignored',
      (tester) async {
    final previous = notifications;
    previous.readGate = Completer<PmcsNotificationStatus>();
    await tester.pumpWidget(subject());
    notifications = FakePhoneNotifications()
      ..status = const PmcsNotificationStatus();
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    previous.readGate!
        .complete(const PmcsNotificationStatus(supported: true, enabled: true));
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isFalse);
    expect(toggle(tester).onChanged, isNull);
    expect(find.text('Phone notifications are unavailable in this version.'),
        findsOneWidget);
  });

  testWidgets(
      'blocked controls remain usable on narrow phones with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    notifications.status =
        const PmcsNotificationStatus(supported: true, enabled: true);
    await tester.pumpWidget(subject(textScale: 2));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Open notification settings'));
    expect(notifications.settingsOpens, 1);
    await tap(tester, find.byType(Switch));
    expect(notifications.enabledChoices, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification preferences never save or reset a profile draft',
      (tester) async {
    final repository =
        FakeProfileRepository(const Profile(uic: 'WJ8TAA', unitName: 'Home'));
    getIt.registerFactory<ProfileViewModel>(() => ProfileViewModel(repository));
    getIt.registerSingleton<PmcsNotificationPort>(notifications);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme, home: const Scaffold(body: ProfilePage())));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Default UIC'), 'W12ABC');
    await tester.enterText(
        find.widgetWithText(CustomTextField, 'Default unit name (optional)'),
        'Unsaved name');
    await tester.pumpAndSettle();
    await tap(tester, find.byType(Switch));
    final state = tester.state<ProfilePageState>(find.byType(ProfilePage));
    expect(state.uicController.text, 'W12ABC');
    expect(state.unitNameController.text, 'Unsaved name');
    expect(state.viewModel.isDirty, isTrue);
    expect(repository.saved, isEmpty);
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(notifications.enabledChoices, [true]);
  });
}
