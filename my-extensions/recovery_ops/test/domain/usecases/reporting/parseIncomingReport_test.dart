import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/domain/usecases/reporting/parseIncomingReport.dart';

sdk.IncomingMessage makeMessage({
  String fromCallsign = 'Alpha',
  Map<String, dynamic>? payloadOverride,
  String? rawPayload,
}) {
  final payload = rawPayload ??
      jsonEncode(payloadOverride ??
          {
            'type': 'recovery_request',
            'entityId': 'entity-1',
            'bumperNumber': 'HQ-42',
            'issue': 'flat tire',
            'recoveryType': 'Wrecker',
            'latitude': 33.0,
            'longitude': -84.0,
            'timestamp': '2026-03-24T12:00:00.000Z',
          });
  return sdk.IncomingMessage(
    id: 'msg-1',
    fromPeerId: 'peer-1',
    fromCallsign: fromCallsign,
    payload: payload,
    receivedAt: DateTime.now(),
  );
}

void main() {
  late ParseIncomingReport usecase;

  setUp(() {
    usecase = ParseIncomingReport();
  });

  test('parses a valid recovery_request message', () {
    final result = usecase.call(makeMessage());

    expect(result, isNotNull);
    expect(result!.fromCallsign, 'Alpha');
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, 'Wrecker');
    expect(result.latitude, 33.0);
    expect(result.longitude, -84.0);
    expect(result.entityId, 'entity-1');
    expect(result.timestamp, DateTime.utc(2026, 3, 24, 12, 0));
  });

  test('returns null for non recovery_request type', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {
        'type': 'chat',
        'text': 'hello',
      },
    ));
    expect(result, isNull);
  });

  test('returns null for malformed JSON', () {
    final result = usecase.call(makeMessage(rawPayload: 'not json'));
    expect(result, isNull);
  });

  test('returns null when required fields are missing', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {'type': 'recovery_request'},
    ));
    expect(result, isNull);
  });

  test('returns null when type field is absent', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {
        'bumperNumber': 'HQ-42',
        'issue': 'flat tire',
        'recoveryType': 'Wrecker',
        'latitude': 33.0,
        'longitude': -84.0,
        'timestamp': '2026-03-24T12:00:00.000Z',
      },
    ));
    expect(result, isNull);
  });

  test('handles integer latitude/longitude', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {
        'type': 'recovery_request',
        'entityId': 'entity-1',
        'bumperNumber': 'HQ-42',
        'issue': 'flat tire',
        'recoveryType': 'Wrecker',
        'latitude': 33,
        'longitude': -84,
        'timestamp': '2026-03-24T12:00:00.000Z',
      },
    ));
    expect(result, isNotNull);
    expect(result!.latitude, 33.0);
    expect(result.longitude, -84.0);
  });

  test('returns null when entityId is missing', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {
        'type': 'recovery_request',
        'bumperNumber': 'HQ-42',
        'issue': 'flat tire',
        'recoveryType': 'Wrecker',
        'latitude': 33.0,
        'longitude': -84.0,
        'timestamp': '2026-03-24T12:00:00.000Z',
      },
    ));
    expect(result, isNull);
  });

  test('returns null when entityId is empty string', () {
    final result = usecase.call(makeMessage(
      payloadOverride: {
        'type': 'recovery_request',
        'entityId': '',
        'bumperNumber': 'HQ-42',
        'issue': 'flat tire',
        'recoveryType': 'Wrecker',
        'latitude': 33.0,
        'longitude': -84.0,
        'timestamp': '2026-03-24T12:00:00.000Z',
      },
    ));
    expect(result, isNull);
  });
}
