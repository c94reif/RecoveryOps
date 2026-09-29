/// Keeps the OCR's letters and digits intact, including O/0 and I/1. These are
/// choices to review, not validated vehicle identifiers or an automatic match.
List<String> findBumperMarkings(Iterable<String> lines) {
  final markings = <String>{};
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
    markings.add(line);
  }
  return markings.toList(growable: false);
}
