import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_rank.dart';

void main() {
  const front = [
    'UNITED STATES GOVERNMENT',
    'Uniformed Services',
    'Army',
    'Name',
    'SMITH, JOHN A',
    'Rank',
    'SGT',
    'Expires',
    '2029 SEP 30',
  ];

  test('reads the rank under its label among the other card fields', () {
    expect(findCacRank(front), 'SGT');
  });

  test('reads a rank printed on the label line', () {
    expect(findCacRank(['Rank: SSG']), 'SSG');
    expect(findCacRank(['RANK 1SG']), '1SG');
  });

  test('keeps a two-word rank together and leaves a pay grade behind', () {
    expect(findCacRank(['Rank', 'Lt Col']), 'LTCOL');
    expect(findCacRank(['RANK MAJ GEN']), 'MAJGEN');
    expect(findCacRank(['Rank', 'SGT E05']), 'SGT');
    expect(findCacRank(['Rank', 'LT']), 'LT');
  });

  test('knows the ranks of every service', () {
    for (final rank in ['SPC', 'CW3', 'GYSGT', 'PO2', 'LTJG', 'A1C', 'SPC4']) {
      expect(findCacRank(['Rank', rank]), rank);
    }
  });

  test('gives no rank rather than a guess', () {
    for (final lines in [
      <String>[],
      ['SGT'],
      ['Rank'],
      ['Rank', 'E05'],
      ['Rank', 'SG7'],
      ['Rank', 'SMITH, JOHN A'],
      ['Pay Grade', 'E05'],
    ]) {
      expect(findCacRank(lines), isNull, reason: '$lines');
    }
  });

  test('refuses two different ranks instead of choosing one', () {
    expect(findCacRank(['Rank SGT', 'Rank SSG']), isNull);
    expect(findCacRank(['Rank SGT', 'RANK', 'SGT']), 'SGT');
  });
}
