import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_card_dates.dart';

void main() {
  group('expiredAt', () {
    test('compares days, not instants', () {
      final expiresOn = DateTime.utc(2026, 3, 24);

      expect(CacCardDates.expiredAt(expiresOn, DateTime.utc(2026, 3, 24, 23)),
          isFalse);
      expect(
          CacCardDates.expiredAt(expiresOn, DateTime.utc(2026, 3, 25)), isTrue);
    });
  });

  group('plausible', () {
    test('a card expires after it is issued and within three years', () {
      final issued = DateTime.utc(2026, 9, 30);

      expect(CacCardDates.plausible(issued, DateTime.utc(2029, 9, 30)), isTrue);
      expect(
          CacCardDates.plausible(issued, DateTime.utc(2026, 9, 30)), isFalse);
      expect(CacCardDates.plausible(issued, DateTime.utc(2025, 1, 1)), isFalse);
      expect(CacCardDates.plausible(issued, DateTime.utc(2030, 1, 1)), isFalse);
    });
  });

  group('daysBetween', () {
    test('counts calendar days, whatever the hour', () {
      expect(
          CacCardDates.daysBetween(
              DateTime.utc(2026, 3, 24, 23), DateTime.utc(2026, 3, 25)),
          1);
      expect(
          CacCardDates.daysBetween(
              DateTime.utc(2026, 3, 24), DateTime.utc(2026, 3, 21, 22)),
          -3);
    });
  });
}
