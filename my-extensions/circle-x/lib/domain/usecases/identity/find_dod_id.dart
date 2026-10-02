import 'package:circle_x/domain/entities/cac_identity.dart';

String? findDodId(Iterable<String> lines) => inspectDodId(lines).dodId;

/// Keeps the complete numeric field so a short read can guide another frame.
/// An incomplete labelled ID must never fall back to a different card number.
({String? dodId, int? digitCount}) inspectDodId(Iterable<String> lines) {
  final labelled = <String>{};
  final unlabelled = <String>{};
  var sawIdLabel = false;
  _Field? pendingField;

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    var field = pendingField;
    pendingField = null;
    for (final match in _tokens.allMatches(line)) {
      final label = match.group(1);
      if (label != null) {
        field = _benefitsLabel.hasMatch(label) ? _Field.benefits : _Field.id;
        sawIdLabel |= field == _Field.id;
        // ML Kit sometimes puts a field's label on its own line.
        pendingField = field;
        continue;
      }

      pendingField = null;
      if (field == _Field.benefits) continue;
      // Reject digits embedded in an OCR word instead of dropping the letter.
      if ((match.start > 0 && _letter.hasMatch(line[match.start - 1])) ||
          (match.end < line.length && _letter.hasMatch(line[match.end]))) {
        continue;
      }
      final digits = match.group(2)!.replaceAll(_separators, '');
      if (field == _Field.id) {
        labelled.add(digits);
      } else if (digits.length >= 9) {
        unlabelled.add(digits);
      }
    }
  }

  final candidates = sawIdLabel ? labelled : unlabelled;
  if (candidates.length != 1) return (dodId: null, digitCount: null);
  final digits = candidates.single;
  return (
    dodId: CacIdentity.isValidEdipi(digits) ? digits : null,
    digitCount: digits.length,
  );
}

enum _Field { id, benefits }

// Consume the whole number, including OCR spacing and dashes, before checking
// its length. Matching just ten digits can accept a fragment of a longer field.
final _tokens = RegExp(
  r'\b((?:DOD\s+)?(?:ID|BENEFITS)(?:\s+NUMBER)?|DBN)\b|'
  r'([0-9]+(?:[ \t\u00a0-]+[0-9]+)*)',
  caseSensitive: false,
);
final _benefitsLabel = RegExp(r'BENEFITS|DBN', caseSensitive: false);
final _letter = RegExp(r'[A-Za-z]');
final _separators = RegExp(r'[ \t\u00a0-]+');
