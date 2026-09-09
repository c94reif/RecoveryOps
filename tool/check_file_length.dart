/// Enforces the project's 400-executable-line component rule (see CLAUDE.md).
///
/// Usage:
///   dart run tool/check_file_length.dart [paths...]
///
/// With no arguments it scans `lib/`. Any `.dart` files or directories passed
/// as arguments are scanned instead. Generated files are always skipped.
///
/// Exits with a non-zero status if any component exceeds [maxExecutableLines],
/// making it suitable for use in a pre-commit hook.
library;

import 'dart:io';

import 'file_length_checker.dart';
import 'generated_files.dart';

/// Directories scanned when no explicit paths are provided.
const List<String> defaultRoots = <String>['lib'];

/// Collects every non-generated Dart file reachable from [paths].
List<File> collectDartFiles(List<String> paths) {
  final dartFiles = <File>[];

  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      if (path.endsWith('.dart') && !isGeneratedDartFile(path)) {
        dartFiles.add(File(path));
      }
    } else if (type == FileSystemEntityType.directory) {
      final entries = Directory(path).listSync(recursive: true);
      for (final entry in entries) {
        if (entry is File &&
            entry.path.endsWith('.dart') &&
            !isGeneratedDartFile(entry.path)) {
          dartFiles.add(entry);
        }
      }
    }
  }

  return dartFiles;
}

void main(List<String> arguments) {
  final roots = arguments.isEmpty ? defaultRoots : arguments;
  final dartFiles = collectDartFiles(roots);

  final violations = <({String path, int lines})>[];
  for (final file in dartFiles) {
    final lines = countExecutableLines(file.readAsStringSync());
    if (lines > maxExecutableLines) {
      violations.add((path: file.path, lines: lines));
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      '✅ File length check passed '
      '(${dartFiles.length} files ≤ $maxExecutableLines executable lines).',
    );
    return;
  }

  violations.sort((a, b) => b.lines.compareTo(a.lines));
  stderr.writeln(
    '🚫 ${violations.length} file(s) exceed the '
    '$maxExecutableLines executable-line limit '
    '(imports and comments excluded):',
  );
  for (final violation in violations) {
    stderr.writeln('   ${violation.lines} lines  ${violation.path}');
  }
  stderr.writeln('\nSplit these components before committing.');
  exitCode = 1;
}
