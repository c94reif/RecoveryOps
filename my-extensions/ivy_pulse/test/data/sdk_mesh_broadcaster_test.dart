import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/services/sdk_mesh_broadcaster.dart';

import '../support/fakes.dart';

/// Stands in for the host's mesh radio. Every send is recorded so a test can
/// assert what actually went out over the air.
class FakeMessagingService implements sdk.MessagingService {
  final List<String> broadcasts = [];
  List<sdk.DeliveryResult> results = const [
    sdk.DeliveryResult(peerId: 'peer-1', success: true),
  ];
  bool throwsOnBroadcast = false;

  @override
  Future<sdk.DeliveryReport> broadcast(String payload) async {
    if (throwsOnBroadcast) throw Exception('mesh radio is down');
    broadcasts.add(payload);
    return sdk.DeliveryReport(results: results);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeMessagingService messaging;
  late SdkMeshBroadcaster broadcaster;

  setUp(() {
    messaging = FakeMessagingService();
    broadcaster = SdkMeshBroadcaster(messaging: messaging);
  });

  group('broadcastPmcsReport', () {
    test('succeeds when at least one peer acknowledged', () async {
      messaging.results = const [
        sdk.DeliveryResult(peerId: 'peer-1', success: false, error: 'timeout'),
        sdk.DeliveryResult(peerId: 'peer-2', success: true),
      ];

      expect(await broadcaster.broadcastPmcsReport(buildReport()), isTrue);
    });

    test('fails when every delivery failed', () async {
      messaging.results = const [
        sdk.DeliveryResult(peerId: 'peer-1', success: false, error: 'timeout'),
        sdk.DeliveryResult(peerId: 'peer-2', success: false, error: 'timeout'),
      ];

      expect(await broadcaster.broadcastPmcsReport(buildReport()), isFalse);
    });

    test('fails when no peer was on the net to hear it', () async {
      messaging.results = const [];

      expect(await broadcaster.broadcastPmcsReport(buildReport()), isFalse);
    });

    test('fails without propagating when the messaging service throws',
        () async {
      messaging.throwsOnBroadcast = true;

      await expectLater(
          broadcaster.broadcastPmcsReport(buildReport()), completion(isFalse));
    });

    test('the payload on the air is the encoded report', () async {
      await broadcaster.broadcastPmcsReport(buildReport(entityId: 'report-7'));

      final body =
          jsonDecode(messaging.broadcasts.single) as Map<String, Object?>;
      expect(body['type'], AppConstants.meshReportType);
      expect(body['entityId'], 'report-7');
    });
  });

  group('broadcastPmcsDeletion', () {
    test('goes out as a broadcast carrying the withdrawn entity id', () async {
      final ok = await broadcaster.broadcastPmcsDeletion('report-7');

      expect(ok, isTrue);
      final body =
          jsonDecode(messaging.broadcasts.single) as Map<String, Object?>;
      expect(body['type'], AppConstants.meshDeletionType);
      expect(body['entityId'], 'report-7');
    });

    test('fails when no peer acknowledged the withdrawal', () async {
      messaging.results = const [
        sdk.DeliveryResult(peerId: 'peer-1', success: false),
      ];

      expect(await broadcaster.broadcastPmcsDeletion('report-7'), isFalse);
    });

    test('fails without propagating when the messaging service throws',
        () async {
      messaging.throwsOnBroadcast = true;

      await expectLater(
          broadcaster.broadcastPmcsDeletion('report-7'), completion(isFalse));
    });
  });

  group('broadcastEncodedReport', () {
    test('re-broadcasts a queued payload verbatim', () async {
      final ok = await broadcaster.broadcastEncodedReport('{"queued":true}');

      expect(ok, isTrue);
      expect(messaging.broadcasts, ['{"queued":true}']);
    });

    test('fails when every delivery failed', () async {
      messaging.results = const [
        sdk.DeliveryResult(peerId: 'peer-1', success: false),
      ];

      expect(await broadcaster.broadcastEncodedReport('{}'), isFalse);
    });

    test('fails without propagating when the messaging service throws',
        () async {
      messaging.throwsOnBroadcast = true;

      await expectLater(
          broadcaster.broadcastEncodedReport('{}'), completion(isFalse));
    });
  });

  group('codec wiring', () {
    test('an injected codec is what encodes the report', () async {
      final codec = FakeReportCodec();
      broadcaster = SdkMeshBroadcaster(messaging: messaging, codec: codec);

      await broadcaster.broadcastPmcsReport(buildReport(entityId: 'report-9'));

      expect(codec.encoded, hasLength(1));
      expect(messaging.broadcasts, ['encoded:report-9']);
    });
  });
}
