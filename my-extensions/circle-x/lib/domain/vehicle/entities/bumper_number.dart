abstract final class BumperNumber {
  static final _whitespace = RegExp(r'\s+');
  static final _hyphens = RegExp(r'[-\u2010-\u2015\u2212\uFE63\uFF0D]');

  static String normalize(String value) =>
      value.replaceAll(_whitespace, '').toUpperCase();

  static String matchingKey(String value) =>
      normalize(value).replaceAll(_hyphens, '');
}
