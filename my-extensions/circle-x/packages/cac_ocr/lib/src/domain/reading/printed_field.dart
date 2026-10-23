List<String> normalizedCacLines(Iterable<String> lines) => [
      for (final line in lines)
        if (_normalize(line) case final normalized when normalized.isNotEmpty)
          normalized,
    ];

String _normalize(String line) => line
    .toUpperCase()
    .replaceAll(RegExp('[’‘]'), "'")
    .replaceAll(RegExp('[‐‑–]'), '-')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

T? readLabelledField<T extends Object>(
  List<String> lines,
  RegExp label,
  T? Function(String rest, String? below) value, {
  RegExp? unless,
}) {
  final found = <T>{};
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final match = label.firstMatch(line);
    if (match == null || (unless?.hasMatch(line) ?? false)) continue;
    final below = index + 1 < lines.length ? lines[index + 1] : null;
    if (value(line.substring(match.end), below) case final read?) {
      found.add(read);
    }
  }
  return found.length == 1 ? found.single : null;
}
