import 'package:cac_ocr/src/domain/reading/printed_field.dart';

DateTime? findCacExpiry(Iterable<String> rawLines) =>
    _labelledDate(rawLines, _expiryLabel, unless: _issueLabel);

DateTime? findCacIssueDate(Iterable<String> rawLines) =>
    _labelledDate(rawLines, _issueLabel, unless: _expiryLabel);

DateTime? _labelledDate(Iterable<String> rawLines, RegExp label,
        {required RegExp unless}) =>
    readLabelledField(
      normalizedCacLines(rawLines),
      label,
      (rest, below) => rest.isNotEmpty
          ? _dateAtStart(rest)
          : below == null
              ? null
              : _wholeDate(below),
      unless: unless,
    );

final _expiryLabel = RegExp(
    r'\b(?:EXPIRATION(?: DATE)?|EXPIRES|EXPIRY|EXP(?: DATE)?)\b\s*[:\-]?\s*');
final _issueLabel = RegExp(r'\b(?:ISSUED|ISSUE(?: DATE)?)\b\s*[:\-]?\s*');

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC'
];
final _monthPattern = _months.join('|');
final _yearFirst =
    RegExp('^(\\d{4}) ?($_monthPattern) ?(\\d{1,2})(?![0-9A-Z])');
final _dayFirst = RegExp('^(\\d{1,2}) ?($_monthPattern) ?(\\d{4})(?![0-9A-Z])');

DateTime? _dateAtStart(String value) {
  if (_yearFirst.firstMatch(value) case final match?) {
    return _date(match.group(1)!, match.group(2)!, match.group(3)!);
  }
  if (_dayFirst.firstMatch(value) case final match?) {
    return _date(match.group(3)!, match.group(2)!, match.group(1)!);
  }
  return null;
}

DateTime? _wholeDate(String value) {
  final match = _yearFirst.firstMatch(value) ?? _dayFirst.firstMatch(value);
  return match != null && match.end == value.length
      ? _dateAtStart(value)
      : null;
}

DateTime? _date(String year, String month, String day) {
  final date =
      DateTime.utc(int.parse(year), _months.indexOf(month) + 1, int.parse(day));
  return date.day == int.parse(day) && date.year >= 2000 ? date : null;
}
