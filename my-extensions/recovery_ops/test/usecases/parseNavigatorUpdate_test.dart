import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/usecases/navigation/parseNavigatorUpdate.dart';

sdk.IncomingMessage makeMessage(Map<String, dynamic> payload) {
  return sdk.IncomingMessage(
    id: 'msg-1',
    fromPeerId: 'peer-1',
    fromCallsign: 'Rescuer',
    payload: jsonEncode(payload),
    receivedAt: DateTime.now(),
  );
}

void main() {
  late ParseNavigatorUpdate parser;

  setUp(() {
    parser = ParseNavigatorUpdate();
  });

  test('parses valid navigator_update message', () {
    final result = parser(makeMessage({
      'type': 'navigator_update',
      'entityId': 'entity-123',
      'navigatorLatitude': 34.5,
      'navigatorLongitude': -85.5,
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNotNull);
    expect(result!.entityId, 'entity-123');
    expect(result.navigatorLatitude, 34.5);
    expect(result.navigatorLongitude, -85.5);
  });

  test('returns null for recovery_request type', () {
    final result = parser(makeMessage({
      'type': 'recovery_request',
      'bumperNumber': 'HQ-42',
      'issue': 'flat tire',
      'recoveryType': 'Wrecker',
      'latitude': 33.0,
      'longitude': -84.0,
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNull);
  });

  test('returns null for unknown type', () {
    final result = parser(makeMessage({
      'type': 'chat',
      'text': 'hello',
    }));

    expect(result, isNull);
  });

  test('returns null for malformed JSON', () {
    final result = parser(sdk.IncomingMessage(
      id: 'msg-1',
      fromPeerId: 'peer-1',
      fromCallsign: 'Rescuer',
      payload: 'not json',
      receivedAt: DateTime.now(),
    ));

    expect(result, isNull);
  });

  test('returns null when required fields are missing', () {
    final result = parser(makeMessage({
      'type': 'navigator_update',
      'entityId': 'entity-123',
    }));

    expect(result, isNull);
  });

  test('parses routeGeometry when present', () {
    final result = parser(makeMessage({
      'type': 'navigator_update',
      'entityId': 'entity-123',
      'navigatorLatitude': 34.5,
      'navigatorLongitude': -85.5,
      'routeGeometry': [
        [34.5, -85.5],
        [34.0, -85.0],
        [33.0, -84.0],
      ],
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNotNull);
    expect(result!.routeGeometry, isNotNull);
    expect(result.routeGeometry!.length, 3);
    expect(result.routeGeometry!.first.latitude, 34.5);
    expect(result.routeGeometry!.last.latitude, 33.0);
  });

  test('parses navigation_stopped message', () {
    final result = parser(makeMessage({
      'type': 'navigation_stopped',
      'entityId': 'entity-456',
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNotNull);
    expect(result!.entityId, 'entity-456');
    expect(result.stopped, isTrue);
  });

  test('navigator_update has stopped false by default', () {
    final result = parser(makeMessage({
      'type': 'navigator_update',
      'entityId': 'entity-123',
      'navigatorLatitude': 34.5,
      'navigatorLongitude': -85.5,
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNotNull);
    expect(result!.stopped, isFalse);
  });

  test('routeGeometry is null when not present', () {
    final result = parser(makeMessage({
      'type': 'navigator_update',
      'entityId': 'entity-123',
      'navigatorLatitude': 34.5,
      'navigatorLongitude': -85.5,
      'timestamp': '2026-03-24T12:00:00.000Z',
    }));

    expect(result, isNotNull);
    expect(result!.routeGeometry, isNull);
  });
}
