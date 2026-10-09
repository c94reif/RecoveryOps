/// Formatting rules for bumper entry and vehicle matching.
///
/// Letters, digits (including leading zeros), and non-hyphen punctuation stay
/// significant. Do not guess at lookalike characters such as O/0 or I/1.
abstract final class BumperNumber {
  static final _whitespace = RegExp(r'\s+');
  static final _hyphens = RegExp(r'[-\u2010-\u2015\u2212\uFE63\uFF0D]');

  /// Cleans typed or pasted input while retaining the bumper's punctuation.
  static String normalize(String value) =>
      value.replaceAll(_whitespace, '').toUpperCase();

  /// Treats optional spaces and hyphens as formatting, including on old reports.
  static String matchingKey(String value) =>
      normalize(value).replaceAll(_hyphens, '');
}
