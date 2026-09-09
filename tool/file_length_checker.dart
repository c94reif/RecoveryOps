/// Counts the "executable" lines of a Dart source file for the project's
/// 400-line component rule (see CLAUDE.md).
///
/// Executable lines exclude:
///   * blank / whitespace-only lines,
///   * `//` line comments and `/* ... */` block comments (including the
///     multi-line variety), and
///   * `import` / `export` / `part` / `library` directives.
///
/// Comment stripping is a heuristic: a `//` or `/*` that appears inside a
/// string literal is treated as the start of a comment. This only affects
/// whether a line is deemed empty, so for line-counting purposes the trade-off
/// is acceptable and keeps the checker dependency-free (no analyzer package).
library;

import 'dart:convert';

/// The maximum number of executable lines a single Dart component may contain.
const int maxExecutableLines = 400;

/// Result of stripping comment text from a single source line.
typedef StrippedLine = ({String code, bool inBlockComment});

/// Removes comment spans from [line], honoring a running block-comment state.
///
/// [inBlockComment] indicates whether the previous line ended inside an
/// unterminated `/* ... */` block. Returns the remaining non-comment code on
/// the line together with the updated block-comment state.
StrippedLine stripComments(String line, {required bool inBlockComment}) {
  final code = StringBuffer();
  var index = 0;
  var withinBlock = inBlockComment;

  while (index < line.length) {
    if (withinBlock) {
      final blockEnd = line.indexOf('*/', index);
      if (blockEnd == -1) {
        // The remainder of the line is still inside the block comment.
        break;
      }
      index = blockEnd + 2;
      withinBlock = false;
      continue;
    }

    final blockStart = line.indexOf('/*', index);
    final lineComment = line.indexOf('//', index);
    final blockStartsFirst =
        blockStart != -1 && (lineComment == -1 || blockStart < lineComment);

    if (blockStartsFirst) {
      code.write(line.substring(index, blockStart));
      index = blockStart + 2;
      withinBlock = true;
      continue;
    }

    if (lineComment != -1) {
      code.write(line.substring(index, lineComment));
      // Everything after `//` is a line comment.
      index = line.length;
      continue;
    }

    code.write(line.substring(index));
    index = line.length;
  }

  return (code: code.toString(), inBlockComment: withinBlock);
}

/// Whether [code] (already stripped of comments) is a Dart directive that does
/// not count toward the executable-line total.
bool isDirective(String code) {
  final trimmed = code.trimLeft();
  return trimmed.startsWith('import ') ||
      trimmed.startsWith('export ') ||
      trimmed.startsWith('part ') ||
      trimmed.startsWith('library ') ||
      trimmed.startsWith('library;');
}

/// Counts the executable lines in [source] per the rules documented above.
int countExecutableLines(String source) {
  var executableLines = 0;
  var inBlockComment = false;

  for (final line in const LineSplitter().convert(source)) {
    final stripped = stripComments(line, inBlockComment: inBlockComment);
    inBlockComment = stripped.inBlockComment;

    final code = stripped.code.trim();
    if (code.isEmpty) continue;
    if (isDirective(code)) continue;

    executableLines++;
  }

  return executableLines;
}
