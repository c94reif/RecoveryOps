import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/reference/common_part.dart';

/// Ranks the common-parts list against a fault so the operator gets the right
/// NSN in one tap instead of scrolling twenty of them under a vehicle.
///
/// Matching is keyword overlap between the fault's component and condition and
/// the part's name — deliberately simple and offline.
class SuggestPartsForFault {
  final List<CommonPart> catalog;

  const SuggestPartsForFault(this.catalog);

  static const _stopWords = {
    'the',
    'and',
    'for',
    'set',
    'kit',
    'assembly',
    'all',
    'not',
    'left',
    'right',
    'front',
    'rear',
    'missing',
    'damaged',
    'loose',
    'low',
    'bad',
  };

  List<CommonPart> call(PmcsFault fault, {int limit = 4}) {
    final terms = _terms('${fault.subcategory} ${fault.condition}');
    if (terms.isEmpty) return const [];

    final scored = <(int, CommonPart)>[];
    for (final part in catalog) {
      final partTerms = _terms(part.name);
      var score = 0;
      for (final term in terms) {
        if (partTerms.contains(term)) {
          score += 2;
        } else if (partTerms
            .any((p) => p.startsWith(term) || term.startsWith(p))) {
          score += 1;
        }
      }
      if (score > 0) scored.add((score, part));
    }

    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final entry in scored.take(limit)) entry.$2];
  }

  static Set<String> _terms(String source) {
    return source
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .toSet();
  }
}
