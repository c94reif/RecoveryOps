import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/domain/entities/recoveryReport.dart';

void main() {
  final now = DateTime.utc(2026, 3, 24, 12, 0, 0);

  RecoveryReport makeReport({
    int? id,
    String fromCallsign = 'Ghost',
    String bumperNumber = 'HQ-42',
    String issue = 'flat tire',
    String recoveryType = 'Wrecker',
    double latitude = 33.0,
    double longitude = -84.0,
    DateTime? timestamp,
    bool isOutgoing = false,
    bool isRead = false,
  }) {
    return RecoveryReport(
      id: id,
      fromCallsign: fromCallsign,
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? now,
      isOutgoing: isOutgoing,
      isRead: isRead,
    );
  }

  group('constructor', () {
    test('sets all required fields', () {
      final r = makeReport();
      expect(r.fromCallsign, 'Ghost');
      expect(r.bumperNumber, 'HQ-42');
      expect(r.issue, 'flat tire');
      expect(r.recoveryType, 'Wrecker');
      expect(r.latitude, 33.0);
      expect(r.longitude, -84.0);
      expect(r.timestamp, now);
    });

    test('id defaults to null', () {
      expect(makeReport().id, isNull);
    });

    test('isOutgoing defaults to false', () {
      expect(makeReport().isOutgoing, isFalse);
    });

    test('isRead defaults to false', () {
      expect(makeReport().isRead, isFalse);
    });

    test('accepts explicit id', () {
      expect(makeReport(id: 42).id, 42);
    });

    test('accepts explicit isOutgoing and isRead', () {
      final r = makeReport(isOutgoing: true, isRead: true);
      expect(r.isOutgoing, isTrue);
      expect(r.isRead, isTrue);
    });
  });

  group('copyWith', () {
    test('returns new instance with updated isRead', () {
      final original = makeReport();
      final updated = original.copyWith(isRead: true);

      expect(updated.isRead, isTrue);
      expect(original.isRead, isFalse);
    });

    test('preserves all other fields when changing one', () {
      final original = makeReport(id: 5);
      final updated = original.copyWith(isRead: true);

      expect(updated.id, 5);
      expect(updated.fromCallsign, 'Ghost');
      expect(updated.bumperNumber, 'HQ-42');
      expect(updated.issue, 'flat tire');
      expect(updated.recoveryType, 'Wrecker');
      expect(updated.latitude, 33.0);
      expect(updated.longitude, -84.0);
      expect(updated.timestamp, now);
      expect(updated.isOutgoing, isFalse);
    });

    test('can update every field at once', () {
      final later = DateTime.utc(2026, 4, 1);
      final original = makeReport();
      final updated = original.copyWith(
        id: 99,
        fromCallsign: 'Wraith',
        bumperNumber: 'BR-07',
        issue: 'engine failure',
        recoveryType: 'Tow Bar',
        latitude: 40.0,
        longitude: -74.0,
        timestamp: later,
        isOutgoing: true,
        isRead: true,
      );

      expect(updated.id, 99);
      expect(updated.fromCallsign, 'Wraith');
      expect(updated.bumperNumber, 'BR-07');
      expect(updated.issue, 'engine failure');
      expect(updated.recoveryType, 'Tow Bar');
      expect(updated.latitude, 40.0);
      expect(updated.longitude, -74.0);
      expect(updated.timestamp, later);
      expect(updated.isOutgoing, isTrue);
      expect(updated.isRead, isTrue);
    });

    test('calling copyWith with no args returns equivalent copy', () {
      final original = makeReport(id: 10, isOutgoing: true, isRead: true);
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.fromCallsign, original.fromCallsign);
      expect(copy.bumperNumber, original.bumperNumber);
      expect(copy.isRead, original.isRead);
      expect(copy.isOutgoing, original.isOutgoing);
    });
  });
}
