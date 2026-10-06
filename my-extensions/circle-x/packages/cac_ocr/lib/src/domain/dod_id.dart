abstract final class DodId {
  static const int length = 10;
  static const int lowest = 1000000000;
  static const int highest = 9999999999;

  static final _written = RegExp(r'^[1-9][0-9]{9}$');

  static bool isValid(Object? value) =>
      value is String && _written.hasMatch(value);

  static bool isIssued(int value) => value >= lowest && value <= highest;

  static String digitsOf(String typed) => typed.replaceAll(RegExp(r'\D'), '');
}
