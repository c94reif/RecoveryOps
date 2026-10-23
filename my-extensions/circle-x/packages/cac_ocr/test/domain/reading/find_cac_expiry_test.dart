import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_expiry.dart';

void main() {
  test('reads the date under its label among the other card fields', () {
    expect(
      findCacExpiry([
        'UNITED STATES GOVERNMENT',
        'Name',
        'SMITH, JOHN A',
        'Rank',
        'SGT',
        'Expires',
        '2029 SEP 30',
      ]),
      DateTime.utc(2029, 9, 30),
    );
  });

  test('reads the date on the label line, with or without spaces', () {
    expect(findCacExpiry(['Expires 2029 SEP 30']), DateTime.utc(2029, 9, 30));
    expect(findCacExpiry(['EXPIRATION DATE: 2029SEP30']),
        DateTime.utc(2029, 9, 30));
    expect(findCacExpiry(['Exp 30 SEP 2029']), DateTime.utc(2029, 9, 30));
    expect(
        findCacExpiry(['Expiration', '2029SEP05']), DateTime.utc(2029, 9, 5));
  });

  test('never takes the date of birth or an unlabelled date', () {
    expect(findCacExpiry(['Date of Birth 1990JAN15']), isNull);
    expect(findCacExpiry(['2029 SEP 30']), isNull);
    expect(findCacExpiry(['Issued 2026 SEP 30']), isNull);
  });

  test('gives up where the issue date could be mistaken for it', () {
    // Read as a column, the line under the labels is the issue date.
    expect(findCacExpiry(['Issued Expires', '2026 SEP 30', '2029 SEP 30']),
        isNull);
    expect(findCacExpiry(['Expires', '2026 SEP 30 2029 SEP 30']), isNull);
  });

  test('refuses two different expiry dates instead of choosing one', () {
    expect(
        findCacExpiry(['Expires 2029 SEP 30', 'Expires 2024 SEP 30']), isNull);
    expect(findCacExpiry(['Expires 2029 SEP 30', 'EXPIRES', '2029SEP30']),
        DateTime.utc(2029, 9, 30));
  });

  test('does not repair a misread or invent a calendar day', () {
    for (final lines in [
      ['Expires 2029 SEP 3O'],
      ['Expires 2029 SEP 31'],
      ['Expires 2029 FEB 30'],
      ['Expires 0029 SEP 30'],
      ['Expires 2029 SEPT 30'],
      ['Expires 2029 SEP 301'],
      ['Expires', 'on 2029 SEP 30'],
      ['Expires INDEF'],
    ]) {
      expect(findCacExpiry(lines), isNull, reason: '$lines');
    }
  });

  test('reads a leap day the calendar has', () {
    expect(findCacExpiry(['Expires 2028 FEB 29']), DateTime.utc(2028, 2, 29));
  });

  group('the issue date', () {
    test('reads under or beside its own label', () {
      expect(findCacIssueDate(['Issued', '2026 SEP 30']),
          DateTime.utc(2026, 9, 30));
      expect(findCacIssueDate(['ISSUE DATE: 2026SEP30']),
          DateTime.utc(2026, 9, 30));
    });

    test('is never taken from the expiry field', () {
      expect(findCacIssueDate(['Expires 2029 SEP 30']), isNull);
      expect(findCacIssueDate(['Issued Expires', '2026 SEP 30']), isNull);
    });
  });
}
