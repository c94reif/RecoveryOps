import 'package:circle_x/data/services/android_pmcs_notifications.dart';
import 'package:circle_x/domain/services/pmcs_notification_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const port = AndroidPmcsNotifications();
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(AndroidPmcsNotifications.channel,
        (call) async {
      calls.add(call);
      return {
        'supported': true,
        'enabled': true,
        'permissionGranted': false,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(AndroidPmcsNotifications.channel, null);
  });

  test('status keeps local opt-in separate from OS permission', () async {
    final state = await port.getStatus();
    expect(state.supported, isTrue);
    expect(state.enabled, isTrue);
    expect(state.permissionGranted, isFalse);
    expect(calls.single.method, 'getStatus');
  });

  test('only the explicit toggle requests an enabled state', () async {
    await port.getStatus();
    await port.rememberReports(['existing']);
    await port.showReport(reportId: 'new', title: 'New PMCS', body: 'B-11');
    expect(calls.any((call) => call.method == 'setEnabled'), isFalse);

    final status = await port.setEnabled(true);
    expect(status.permissionGranted, isFalse);
    expect(calls.last.method, 'setEnabled');
    expect(calls.last.arguments, {'enabled': true});
    await port.setEnabled(false);
    expect(calls.last.arguments, {'enabled': false});
  });

  test('passes stable identity and notification content unchanged', () async {
    await port.showReport(
      reportId: 'circle-x.pmcs.123',
      title: 'New PMCS · Bravo Company (WAB4C0)',
      body: 'B-11 · MISSION CAPABLE',
    );
    expect(calls.single.method, 'showReport');
    expect(calls.single.arguments, {
      'reportId': 'circle-x.pmcs.123',
      'title': 'New PMCS · Bravo Company (WAB4C0)',
      'body': 'B-11 · MISSION CAPABLE',
    });
    await port.showReport(reportId: '', title: 'Invalid', body: 'Ignored');
    expect(calls, hasLength(1));
  });

  test('seeds a large report history in bounded distinct batches', () async {
    final ids = List.generate(601, (index) => 'report-$index');
    await port.rememberReports(['', ...ids, ids.first]);
    expect(calls.map((call) => call.method), everyElement('rememberReports'));
    final batches = calls
        .map((call) => (call.arguments as Map)['reportIds'] as List)
        .toList();
    expect(batches.map((batch) => batch.length), [250, 250, 101]);
    expect(batches.expand((batch) => batch), ids);
  });

  test('opens native notification settings', () async {
    await port.openSettings();
    expect(calls.single.method, 'openSettings');
  });

  test('older hosts without the plugin remain usable', () async {
    messenger.setMockMethodCallHandler(AndroidPmcsNotifications.channel, null);
    final state = await port.getStatus();
    expect(state.supported, isFalse);
    expect((await port.setEnabled(true)).enabled, isFalse);
    await port.rememberReports(['old']);
    await port.showReport(reportId: 'new', title: 'Title', body: 'Body');
    await port.openSettings();
  });

  test('native failures are surfaced to the settings and receipt callers',
      () async {
    messenger.setMockMethodCallHandler(AndroidPmcsNotifications.channel,
        (call) async => throw PlatformException(code: 'storage_failed'));
    await expectLater(port.getStatus(), throwsA(isA<PlatformException>()));
    await expectLater(port.setEnabled(true), throwsA(isA<PlatformException>()));
    await expectLater(
        port.rememberReports(['new']), throwsA(isA<PlatformException>()));
    await expectLater(
        port.showReport(reportId: 'new', title: 'Title', body: 'Body'),
        throwsA(isA<PlatformException>()));
  });

  test('factory only enables the native adapter on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(createPmcsNotifications(), isA<AndroidPmcsNotifications>());
    for (final platform in [TargetPlatform.linux, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(createPmcsNotifications(), isA<SilentPmcsNotificationPort>());
    }
  });

  test('unsupported port never enables phone notifications', () async {
    const unsupported = SilentPmcsNotificationPort();
    expect((await unsupported.getStatus()).supported, isFalse);
    expect((await unsupported.setEnabled(true)).enabled, isFalse);
    await unsupported.openSettings();
    await unsupported.rememberReports(['existing']);
    await unsupported.showReport(reportId: 'new', title: '', body: '');
  });
}
