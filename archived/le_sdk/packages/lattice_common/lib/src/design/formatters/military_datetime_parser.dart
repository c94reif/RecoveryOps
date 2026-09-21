/// Parser and formatter for the `YYYY/MM/DD - HHMM` military datetime mask.
///
/// All values are **device-local time** — not UTC.  Consumers that need UTC
/// should call `.toUtc()` on the returned [DateTime] at the domain boundary.
///
/// Example:
/// ```dart
/// final dt = MilitaryDateTimeParser.parse('2026/05/20 - 1430');
/// // dt == DateTime(2026, 5, 20, 14, 30)  (local)
///
/// final s = MilitaryDateTimeParser.format(DateTime(2026, 5, 20, 14, 30));
/// // s == '2026/05/20 - 1430'
/// ```
class MilitaryDateTimeParser {
  MilitaryDateTimeParser._();

  /// Expected length of a fully-typed mask string.
  static const int _expectedLength = 17;

  /// Parses a fully-completed mask string into a **local** [DateTime].
  ///
  /// Returns `null` if the string is not in the expected format or contains
  /// out-of-range values.  Does NOT validate calendar correctness beyond the
  /// numeric ranges below.
  ///
  /// Valid ranges enforced:
  /// - month : 01–12
  /// - day   : 01–31
  /// - hour  : 00–23
  /// - minute: 00–59
  static DateTime? parse(String input) {
    if (input.length != _expectedLength) return null;

    // Expected: "YYYY/MM/DD - HHMM"
    //            0123456789012345678
    //                    1111111111
    // Validate separators at fixed positions.
    if (input[4] != '/' || input[7] != '/' || input[10] != ' ' ||
        input[11] != '-' || input[12] != ' ') {
      return null;
    }

    final yearStr = input.substring(0, 4);
    final monthStr = input.substring(5, 7);
    final dayStr = input.substring(8, 10);
    final hourStr = input.substring(13, 15);
    final minStr = input.substring(15, 17);

    final year = int.tryParse(yearStr);
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minStr);

    if (year == null || month == null || day == null ||
        hour == null || minute == null) {
      return null;
    }

    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    // Construct as local DateTime (not UTC).
    return DateTime(year, month, day, hour, minute);
  }

  /// Formats a [DateTime] using its **local** components into `YYYY/MM/DD - HHMM`.
  ///
  /// Consumers that have a UTC [DateTime] should call `.toLocal()` first if
  /// local display is desired, or pass the UTC value directly when the field
  /// is meant to show UTC (outside the scope of this field, which is local).
  static String format(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y/$mo/$d - $h$mi';
  }

  /// Validates a (possibly partial) mask string and returns a human-readable
  /// error message, or `null` if the value is valid and complete.
  ///
  /// Returns error strings for:
  /// - incomplete entry (fewer than 17 characters)
  /// - month out of range (01–12)
  /// - day out of range (01–31)
  /// - hour out of range (00–23)
  /// - minute out of range (00–59)
  static String? validate(String input) {
    if (input.length < _expectedLength) {
      return 'Enter a complete date and time (YYYY/MM/DD - HHMM)';
    }

    // Re-use parse logic for separator and length checks.
    if (input[4] != '/' || input[7] != '/' || input[10] != ' ' ||
        input[11] != '-' || input[12] != ' ') {
      return 'Enter a complete date and time (YYYY/MM/DD - HHMM)';
    }

    final month = int.tryParse(input.substring(5, 7));
    final day = int.tryParse(input.substring(8, 10));
    final hour = int.tryParse(input.substring(13, 15));
    final minute = int.tryParse(input.substring(15, 17));

    if (month == null || month < 1 || month > 12) {
      return 'Month must be between 01 and 12';
    }
    if (day == null || day < 1 || day > 31) {
      return 'Day must be between 01 and 31';
    }
    if (hour == null || hour < 0 || hour > 23) {
      return 'Hour must be between 00 and 23';
    }
    if (minute == null || minute < 0 || minute > 59) {
      return 'Minute must be between 00 and 59';
    }

    return null;
  }
}
