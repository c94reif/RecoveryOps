/// Shared knowledge of which Dart files are generated and therefore exempt from
/// the project's component rules (size limit and coverage floor — see CLAUDE.md).
library;

/// Filename suffixes for generated code the component rules do not govern.
const List<String> generatedSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.config.dart',
  '.gr.dart',
  '.mocks.dart',
];

/// Whether [path] refers to generated Dart source.
bool isGeneratedDartFile(String path) =>
    generatedSuffixes.any((suffix) => path.endsWith(suffix));
