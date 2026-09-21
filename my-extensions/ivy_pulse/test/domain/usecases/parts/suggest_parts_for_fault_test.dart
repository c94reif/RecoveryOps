import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/catalog/pmcs_reference_data.g.dart';
import 'package:ivy_pulse/domain/usecases/parts/suggest_parts_for_fault.dart';

import '../../../support/fakes.dart';

void main() {
  const usecase = SuggestPartsForFault(commonParts);

  test('matches a battery fault to the 6T battery', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Battery', condition: 'Corrosion'),
    );

    expect(suggestions.map((p) => p.name), contains('Battery, 6T'));
  });

  test('matches a radiator hose fault to both hoses', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Radiator Hoses', condition: 'Leaking'),
    );

    expect(
      suggestions.map((p) => p.name),
      containsAll(['Radiator Hose, Upper', 'Radiator Hose, Lower']),
    );
  });

  test('matches a brake fluid fault to brake fluid', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Brake Fluid', condition: 'Low'),
    );

    expect(suggestions.map((p) => p.name), contains('Brake Fluid, DOT 5'));
  });

  test('caps the list so a gloved operator is not scrolling', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Tire Condition', condition: 'Cut/Gash'),
      limit: 2,
    );

    expect(suggestions.length, lessThanOrEqualTo(2));
  });

  test('returns nothing rather than noise for an unmatched fault', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Zzz', condition: 'Qqq'),
    );

    expect(suggestions, isEmpty);
  });

  test('ignores generic condition words that match everything', () async {
    final suggestions = usecase(
      buildFault(subcategory: 'Xyz', condition: 'Missing'),
    );

    expect(suggestions, isEmpty);
  });
}
