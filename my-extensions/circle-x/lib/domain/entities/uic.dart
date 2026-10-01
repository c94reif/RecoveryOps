abstract final class Uic {
  static const length = 6;

  static String normalize(String value) => value.trim().toUpperCase();

  static String? validate(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return 'UIC is required';
    if (normalized.length != length) {
      return 'UIC must be exactly 6 characters';
    }
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
      return 'Use only letters A–Z and numbers 0–9';
    }
    return null;
  }

  static bool isValid(String value) => validate(value) == null;
}
