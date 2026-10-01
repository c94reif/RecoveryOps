import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/usecases/identity/find_cac_name.dart';

void main() {
  test('reads a labelled name among the other printed card fields', () {
    expect(
        findCacName([
          'UNITED STATES GOVERNMENT',
          'Uniformed Services',
          'Army',
          'Name',
          'SMITH, JOHN A',
          'Rank',
          'SGT',
          'Expires',
          '2029 SEP 30',
        ]),
        (firstName: 'JOHN A', lastName: 'SMITH'));
  });

  test('keeps full given names, compound surnames, and punctuation', () {
    expect(findCacName(['Name: de la cruz, María Anne-Louise', 'Affiliation']),
        (firstName: 'MARÍA ANNE-LOUISE', lastName: 'DE LA CRUZ'));
    expect(findCacName(['NAME O’NEILL, JOHN']),
        (firstName: 'JOHN', lastName: "O'NEILL"));
  });

  test('handles names wrapped over OCR lines', () {
    expect(findCacName(['NAME', 'SMITH,', 'JOHN', 'MICHAEL', 'GRADE']),
        (firstName: 'JOHN MICHAEL', lastName: 'SMITH'));
    expect(findCacName(['SMITH,', 'JOHN A', 'EXPIRATION']),
        (firstName: 'JOHN A', lastName: 'SMITH'));
  });

  test('accepts a missed comma only within the labelled name field', () {
    expect(findCacName(['NAME', 'SMITH JOHN A', 'RANK']),
        (firstName: 'JOHN A', lastName: 'SMITH'));
    expect(findCacName(['SMITH JOHN A']), isNull);
  });

  test('can use a clear surname-comma-given line when the label is missed', () {
    expect(findCacName(['Army', 'SMITH, JOHN A', 'Rank', 'SGT']),
        (firstName: 'JOHN A', lastName: 'SMITH'));
  });

  test('normalizes whitespace and case for frame agreement', () {
    expect(findCacName([' Name :  smith,  john   a ']),
        (firstName: 'JOHN A', lastName: 'SMITH'));
  });

  test('does not mistake headings, labels, or back-side numbers for a name',
      () {
    for (final lines in [
      <String>[],
      ['UNITED STATES GOVERNMENT', 'Uniformed Services', 'Army', 'SGT'],
      ['NAME', 'RANK', 'SGT'],
      ['NAME', 'SMITH'],
      ['NAME', 'SM1TH, JOHN'],
      ['SMITH,'],
      [', JOHN'],
      ['DEPARTMENT OF DEFENSE, UNITED STATES'],
      ['DoD ID Number 1087987498', 'DoD Benefits Number 10879874981'],
    ]) {
      expect(findCacName(lines), isNull, reason: '$lines');
    }
  });

  test('refuses competing unlabelled names instead of choosing a person', () {
    expect(findCacName(['SMITH, JOHN', 'JONES, MARY']), isNull);
  });

  test('uses the labelled field over another comma-separated line', () {
    expect(findCacName(['NAME: SMITH, JOHN', 'RANK', 'OTHER, PERSON']),
        (firstName: 'JOHN', lastName: 'SMITH'));
  });
}
