import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_expiry.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_rank.dart';
import 'package:cac_ocr/src/domain/reading/printed_field.dart';

void main() {
  final label = RegExp(r'^GRADE\b\s*[:\-]?\s*');
  String? grade(List<String> lines) => readLabelledField(
      normalizedCacLines(lines),
      label,
      (rest, below) => rest.isNotEmpty ? rest : below);

  test('lines are compared in one shape: upper case, plain dashes, one space',
      () {
    expect(normalizedCacLines(['  smith ,  John ', '', 'o’neil – jr']),
        ['SMITH , JOHN', "O'NEIL - JR"]);
  });

  test('a field reads beside its label or on the line below', () {
    expect(grade(['Grade: E05']), 'E05');
    expect(grade(['GRADE', 'E05']), 'E05');
    expect(grade(['GRADE']), isNull);
  });

  test('two labelled lines must agree, or the field reads as nothing', () {
    expect(grade(['GRADE E05', 'GRADE E05']), 'E05');
    expect(grade(['GRADE E05', 'GRADE E06']), isNull);
  });

  test('a line carrying the other label is skipped', () {
    expect(
        readLabelledField(
            normalizedCacLines(['GRADE E05 RANK']), label, (rest, _) => rest,
            unless: RegExp('RANK')),
        isNull);
  });

  test('an en dash after a label reads like a hyphen', () {
    expect(findCacRank(['RANK – SGT']), 'SGT');
    expect(findCacExpiry(['Expires – 2029 SEP 30']), DateTime.utc(2029, 9, 30));
  });
}
