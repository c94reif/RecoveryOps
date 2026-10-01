import 'package:circle_x/domain/entities/cac_name.dart';

/// Reads the NAME field, or an unambiguous LAST, GIVEN line if its label was
/// missed. Never guesses a name from arbitrary unlabelled words on the card.
CacName? findCacName(Iterable<String> rawLines) {
  final lines =
      rawLines.map(_normalize).where((line) => line.isNotEmpty).toList();
  final labelled = <CacName>{};
  final unlabelled = <CacName>{};

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final label = RegExp(r'^NAME\b\s*[:\-]?\s*').firstMatch(line);
    if (label != null) {
      final parts = <String>[];
      final inline = line.substring(label.end);
      if (inline.isNotEmpty) parts.add(inline);
      // Names can wrap over multiple OCR lines. A field label, date, or card
      // heading ends this field instead of becoming part of the person's name.
      for (var next = index + 1;
          next < lines.length && parts.length < 3;
          next++) {
        if (!_isNameText(lines[next])) break;
        parts.add(lines[next]);
      }
      final name = _parse(parts.join(' '), labelled: true);
      if (name != null) labelled.add(name);
    } else if (line.contains(',')) {
      var value = line;
      if (line.endsWith(',') &&
          index + 1 < lines.length &&
          _isNameText(lines[index + 1])) {
        value = '$line ${lines[index + 1]}';
      }
      final name = _parse(value, labelled: false);
      if (name != null) unlabelled.add(name);
    }
  }

  if (labelled.isNotEmpty) return labelled.length == 1 ? labelled.single : null;
  return unlabelled.length == 1 ? unlabelled.single : null;
}

String _normalize(String value) => value
    .toUpperCase()
    .replaceAll(RegExp('[’‘]'), "'")
    .replaceAll(RegExp('[‐‑–]'), '-')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final _nameCharacters = RegExp(r"^[\p{L}\p{M} .,'-]+$", unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _cardWords = RegExp(
  r'\b(NAME|UNITED|STATES|GOVERNMENT|DEPARTMENT|DEFENSE|IDENTIFICATION|'
  r'GENEVA|CONVENTIONS|CONVENTION|CARD|ACCESS|COMMON|AFFILIATION|'
  r'UNIFORMED|SERVICES|SERVICE|ARMY|NAVY|MARINE|CORPS|AIR|FORCE|COAST|'
  r'GUARD|DOD|BENEFITS|NUMBER|ID|RANK|GRADE|PAY|EXPIRATION|EXPIRES|'
  r'ISSUED|DATE|BIRTH|SEX|HEIGHT|WEIGHT|EYES|HAIR|SPONSOR|AGENCY|'
  r'ACTIVE|DUTY|CIVILIAN|CONTRACTOR|RETIRED|RESERVE)\b',
);

bool _isNameText(String value) =>
    value.isNotEmpty &&
    _nameCharacters.hasMatch(value) &&
    !_cardWords.hasMatch(value);

CacName? _parse(String value, {required bool labelled}) {
  if (!_isNameText(value)) return null;
  final commaParts = value.split(',');
  final String lastName;
  final String firstName;
  if (commaParts.length == 2) {
    lastName = commaParts.first.trim();
    firstName = commaParts.last.trim();
  } else if (commaParts.length == 1 && labelled) {
    final words = value.split(' ');
    if (words.length < 2) return null;
    lastName = words.first;
    firstName = words.skip(1).join(' ');
  } else {
    return null;
  }
  if (!_letter.hasMatch(lastName) || !_letter.hasMatch(firstName)) return null;
  return (firstName: firstName, lastName: lastName);
}
