import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/data/services/sdk_mesh_broadcaster.dart';

import '../support/sdk_delivery_fakes.dart';

void main() {
  late RecordingMessagingService messaging;
  late SdkMeshBroadcaster broadcaster;
  const position = LatLng(33.25, -84.5);

  setUp(() {
    messaging = RecordingMessagingService();
    broadcaster = SdkMeshBroadcaster(messaging: messaging);
  });

  Future<bool> publish() => broadcaster.broadcastRecoveryRequest(
        entityId: 'recovery-1',
        bumperNumber: 'HQ-42',
        issue: 'flat tire',
        typeName: 'Wrecker',
        position: position,
      );

  Map<String, dynamic> payload() =>
      jsonDecode(messaging.broadcasts.last) as Map<String, dynamic>;

  test('broadcasts the complete recovery payload with a UTC timestamp',
      () async {
    expect(await publish(), isTrue);
    final body = payload();
    expect(DateTime.parse(body.remove('timestamp') as String).isUtc, isTrue);
    expect(body, {
      'type': 'recovery_request',
      'entityId': 'recovery-1',
      'bumperNumber': 'HQ-42',
      'issue': 'flat tire',
      'recoveryType': 'Wrecker',
      'latitude': 33.25,
      'longitude': -84.5,
    });
  });

  test('one acknowledgement is sufficient despite another peer failing',
      () async {
    messaging.results = const [
      sdk.DeliveryResult(peerId: 'peer-1', success: false),
      sdk.DeliveryResult(peerId: 'peer-2', success: true),
    ];
    expect(await publish(), isTrue);
    expect(await broadcaster.broadcastRecoveryDeletion('recovery-1'), isTrue);
  });

  for (final results in <List<sdk.DeliveryResult>>[
    [],
    [const sdk.DeliveryResult(peerId: 'peer-1', success: false)],
  ]) {
    test('no successful peers means undelivered (${results.length} peers)',
        () async {
      messaging.results = results;
      expect(await publish(), isFalse);
      expect(
          await broadcaster.broadcastRecoveryDeletion('recovery-1'), isFalse);
    });
  }

  test('broadcasts a withdrawal for the same recovery identity', () async {
    expect(await broadcaster.broadcastRecoveryDeletion('recovery-1'), isTrue);
    expect(payload()['type'], 'recovery_request_deleted');
    expect(payload()['entityId'], 'recovery-1');
    expect(DateTime.parse(payload()['timestamp'] as String).isUtc, isTrue);
  });

  test('navigator messages include route points only when available', () async {
    for (final geometry in <List<LatLng>?>[
      null,
      [],
      [position]
    ]) {
      await broadcaster.broadcastNavigatorLocation(
        entityId: 'recovery-1',
        navigatorPosition: position,
        routeGeometry: geometry,
      );
      expect(payload()['type'], 'navigator_update');
      expect(payload()['entityId'], 'recovery-1');
      expect(payload()['navigatorLatitude'], position.latitude);
      expect(payload()['navigatorLongitude'], position.longitude);
      if (geometry == null || geometry.isEmpty) {
        expect(payload().containsKey('routeGeometry'), isFalse);
      } else {
        expect(payload()['routeGeometry'], [
          [33.25, -84.5]
        ]);
      }
    }
  });

  test('broadcasts navigation stopped without a location', () async {
    await broadcaster.broadcastNavigationStopped('recovery-1');
    expect(payload()['type'], 'navigation_stopped');
    expect(payload()['entityId'], 'recovery-1');
    expect(payload().containsKey('navigatorLatitude'), isFalse);
  });

  test('radio exceptions become failures and do not crash navigation',
      () async {
    messaging.failBroadcast = true;
    expect(await publish(), isFalse);
    expect(await broadcaster.broadcastRecoveryDeletion('recovery-1'), isFalse);
    await expectLater(
      broadcaster.broadcastNavigatorLocation(
        entityId: 'recovery-1',
        navigatorPosition: position,
      ),
      completes,
    );
    await expectLater(
      broadcaster.broadcastNavigationStopped('recovery-1'),
      completes,
    );
  });
}
