import 'package:circle_x/domain/entities/bumper_number.dart';

List<String> findBumperMarkings(Iterable<String> lines) {
  final markings = <String, String>{};
  for (final raw in lines) {
    final line = raw
        .toUpperCase()
        .replaceAll(RegExp('[‐‑–—−]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*-\s*'), '-')
        .trim();
    if (line.isEmpty ||
        line.length > 64 ||
        !RegExp(r'^[A-Z0-9][A-Z0-9 ./-]*$').hasMatch(line)) {
      continue;
    }
    markings.putIfAbsent(BumperNumber.matchingKey(line), () => line);
  }
  return markings.values.toList(growable: false);
}
