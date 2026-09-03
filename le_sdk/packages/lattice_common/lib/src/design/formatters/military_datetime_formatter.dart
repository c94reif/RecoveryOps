import 'package:flutter/services.dart';

/// A [TextInputFormatter] that enforces the `YYYY/MM/DD - HHMM` mask for
/// military-style local datetime entry.
///
/// Digit positions in the mask string:
///   mask[0..3]   → year digits  (4 digits)
///   mask[4]      → '/'          (auto-inserted)
///   mask[5..6]   → month digits (2 digits)
///   mask[7]      → '/'          (auto-inserted)
///   mask[8..9]   → day digits   (2 digits)
///   mask[10..12] → ' - '        (auto-inserted)
///   mask[13..14] → hour digits  (2 digits)
///   mask[15..16] → minute digits (2 digits)
///
/// Total mask length = 17 characters when full; accepts max 12 user digits.
///
/// Behaviour:
/// - Only digit keystrokes are accepted; all other characters are stripped.
/// - Separators (`/`, ` - `) are injected automatically at the right positions.
/// - Backspace removes the last digit; the formatter rebuilds from the digit
///   sequence, so separators that are no longer needed vanish automatically.
/// - Typing beyond 12 digits is silently ignored.
class MilitaryDateTimeFormatter extends TextInputFormatter {
  // Mask definition: null = user digit slot, String = literal separator char.
  // Length = 17 slots for the full `YYYY/MM/DD - HHMM` pattern.
  static const List<String?> _mask = [
    null, null, null, null, // YYYY  (slots 0-3)
    '/',                    // sep   (slot 4)
    null, null,             // MM    (slots 5-6)
    '/',                    // sep   (slot 7)
    null, null,             // DD    (slots 8-9)
    ' ', '-', ' ',          // ' - ' (slots 10-12)
    null, null,             // HH    (slots 13-14)
    null, null,             // mm    (slots 15-16)
  ];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digit characters from whatever the user typed/pasted.
    final rawDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Cap at 12 digits (4+2+2+2+2).
    final digits =
        rawDigits.length > 12 ? rawDigits.substring(0, 12) : rawDigits;

    // Rebuild the masked string character by character.
    final buffer = StringBuffer();
    int digitIndex = 0;

    for (int i = 0; i < _mask.length; i++) {
      final slot = _mask[i];
      if (slot == null) {
        // Digit slot — consume the next typed digit.
        if (digitIndex < digits.length) {
          buffer.write(digits[digitIndex]);
          digitIndex++;
        } else {
          // No more digits; stop — don't append trailing separators.
          break;
        }
      } else {
        // Literal separator — only include it if there is at least one more
        // digit that will follow (i.e. the user has already typed past this
        // separator position).
        if (_hasDigitAfter(i, digitIndex, digits.length)) {
          buffer.write(slot);
        } else {
          break;
        }
      }
    }

    final text = buffer.toString();
    // Always place cursor at the end of the rebuilt string.
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Returns true when there is at least one digit slot after mask position
  /// [maskPos] that still has a digit available (i.e. [digitIndex] <
  /// [totalDigits]).
  bool _hasDigitAfter(int maskPos, int digitIndex, int totalDigits) {
    if (digitIndex >= totalDigits) return false;
    for (int i = maskPos + 1; i < _mask.length; i++) {
      if (_mask[i] == null) return true; // found a digit slot after separator
    }
    return false;
  }
}
