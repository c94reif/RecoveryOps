import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/reference/common_part.dart';

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
    final terms =
        _extractSearchTerms('${fault.subcategory} ${fault.condition}');
    if (terms.isEmpty) return const [];

    final scoredParts = <(int, CommonPart)>[];
    for (final part in catalog) {
      final partTerms = _extractSearchTerms(part.name);
      var score = 0;
      for (final term in terms) {
        if (partTerms.contains(term)) {
          score += 2;
        } else if (partTerms.any((partTerm) =>
            partTerm.startsWith(term) || term.startsWith(partTerm))) {
          score += 1;
        }
      }
      if (score > 0) scoredParts.add((score, part));
    }

    scoredParts.sort((first, second) => second.$1.compareTo(first.$1));
    return [for (final entry in scoredParts.take(limit)) entry.$2];
  }

  static Set<String> _extractSearchTerms(String source) {
    return source
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((term) => term.length > 2 && !_stopWords.contains(term))
        .toSet();
  }
}
