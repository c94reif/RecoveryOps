import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';

void main() {
  const smith = (firstName: 'JOHN A', lastName: 'SMITH');

  test('progress counts agreeing frames, and drops the count when contested',
      () {
    expect(
        const CacReadingProgress(CacScanSide.front, agreeing: 2, needed: 3)
            .message,
        'Reading your name — hold still · 2 of 3');
    expect(
        const CacReadingProgress(CacScanSide.back, agreeing: null, needed: 3)
            .message,
        'Reading the 10-digit DoD ID number — hold still');
  });

  test('the flip names who was read, with the rank when there is one', () {
    expect(
        const CacFlipCard(smith, rank: 'SGT').message,
        'Name read: SGT SMITH, JOHN A. Flip to the BACK — hold the DoD ID '
        'number above the wide strip steady');
    expect(const CacFlipCard(smith).message, startsWith('Name read: SMITH,'));
  });

  test('a wrong digit count says whether it was short or long', () {
    expect(const CacDigitCount(9).message, startsWith('Read 9 of 10 digits.'));
    expect(const CacDigitCount(11).message,
        startsWith('Read 11 digits; DoD ID must be exactly 10.'));
  });

  test('equal guidance is equal, so a viewfinder is not told twice', () {
    expect(const CacReadingProgress(CacScanSide.front, agreeing: 1, needed: 3),
        const CacReadingProgress(CacScanSide.front, agreeing: 1, needed: 3));
    expect(
        const CacReadingProgress(CacScanSide.front, agreeing: 1, needed: 3)
            .hashCode,
        const CacReadingProgress(CacScanSide.front, agreeing: 1, needed: 3)
            .hashCode);
    expect(
        const CacReadingProgress(CacScanSide.front, agreeing: 1, needed: 3),
        isNot(const CacReadingProgress(CacScanSide.back,
            agreeing: 1, needed: 3)));
    expect(const CacFlipCard(smith, rank: 'SGT'),
        const CacFlipCard(smith, rank: 'SGT'));
    expect(
        const CacFlipCard(smith).hashCode, const CacFlipCard(smith).hashCode);
    expect(
        const CacFlipCard(smith), isNot(const CacFlipCard(smith, rank: 'SGT')));
    expect(const CacDigitCount(9), const CacDigitCount(9));
    expect(const CacDigitCount(9).hashCode, const CacDigitCount(9).hashCode);
    expect(const CacDigitCount(9), isNot(const CacDigitCount(11)));
  });

  test('every instruction has words', () {
    for (final instruction in CacInstruction.values) {
      expect(instruction.message, isNotEmpty, reason: instruction.name);
    }
  });
}
