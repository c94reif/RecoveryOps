import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';

/// Picks the DoD ID number out of the text OCR read off the back of a CAC.
///
/// The back of the card prints several numbers close together: the ten-digit
/// **DoD ID Number**, the eleven-digit DoD Benefits Number directly beneath
/// it, and the date of birth as eight digits. OCR hands them back as lines,
/// often with the label on the same line as its value and sometimes with the
/// digits split by a space where the card's holographic overlay crosses them.
///
/// So the rule is shape first, then label. A run of exactly ten digits —
/// after the spaces inside a line are closed up — that falls in the range
/// DEERS actually issues is a DoD ID; an eleven-digit run is the benefits
/// number and is never a candidate even though its first nine digits are the
/// same Soldier. When more than one ten-digit run survives, the one on a
/// line that mentions "ID" wins, because that is the labelled one.
///
/// Pure so it is testable against recorded OCR output without a camera. What
/// it returns is a candidate for `ParseDodId` to validate, not a verdict.
String? findDodId(Iterable<String> lines) {
  String? labelled;
  String? unlabelled;

  for (final rawLine in lines) {
    // Close up digit runs the overlay split, but not across letters: the
    // benefits number is not to be joined onto the ID by a stray space.
    final line = rawLine.replaceAllMapped(
      RegExp(r'(\d)[  ](?=\d)'),
      (m) => m.group(1)!,
    );

    for (final match in RegExp(r'(?<!\d)(\d{10})(?!\d)').allMatches(line)) {
      final digits = match.group(1)!;
      final value = int.parse(digits);
      if (value < ParseCacBarcode.lowestEdipi ||
          value > ParseCacBarcode.highestEdipi) {
        continue;
      }
      if (_mentionsId(line)) {
        labelled ??= digits;
      } else {
        unlabelled ??= digits;
      }
    }
  }

  return labelled ?? unlabelled;
}

/// "DoD ID Number", "DOD ID", "ID NUMBER" — however OCR cased or spaced it.
bool _mentionsId(String line) {
  final upper = line.toUpperCase();
  return RegExp(r'\bID\b').hasMatch(upper) || upper.contains('DOD');
}
