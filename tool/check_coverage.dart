/// Enforces the project's 80% line-coverage rule (see CLAUDE.md).
///
/// Usage:
///   flutter test --coverage
///   dart run tool/check_coverage.dart [--min=80] [path/to/lcov.info]
///
/// Reads `coverage/lcov.info` by default, computes total line coverage across
/// non-generated files, and exits non-zero if it falls below the threshold.
/// Files individually below the threshold are listed as guidance.
library;

import 'dart:io';

import 'coverage_report.dart';

/// Default location `flutter test --coverage` writes its report to.
const String defaultLcovPath = 'coverage/lcov.info';

/// Parses `--min=<percent>` from [arguments], defaulting to the project floor.
double parseThreshold(List<String> arguments) {
  for (final argument in arguments) {
    if (argument.startsWith('--min=')) {
      final value = double.tryParse(argument.substring('--min='.length));
      if (value != null) return value;
    }
  }
  return minimumCoveragePercent;
}

/// Resolves the lcov path from the first non-flag argument, or the default.
String parseLcovPath(List<String> arguments) {
  for (final argument in arguments) {
    if (!argument.startsWith('--')) return argument;
  }
  return defaultLcovPath;
}

void main(List<String> arguments) {
  final threshold = parseThreshold(arguments);
  final lcovPath = parseLcovPath(arguments);

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln('🚫 No coverage report found at "$lcovPath".');
    stderr.writeln('   Run "flutter test --coverage" first.');
    exitCode = 1;
    return;
  }

  final files = parseLcov(lcovFile.readAsStringSync());
  if (files.isEmpty) {
    stderr.writeln('🚫 Coverage report "$lcovPath" contained no records.');
    exitCode = 1;
    return;
  }

  final summary = summarize(files);
  final percent = summary.percent.toStringAsFixed(1);

  final belowFiles = filesBelowThreshold(files, threshold: threshold);
  if (belowFiles.isNotEmpty) {
    stdout.writeln('Files below ${threshold.toStringAsFixed(0)}% coverage:');
    for (final file in belowFiles) {
      final ratio = (file.linesHit / file.linesFound) * 100;
      stdout.writeln(
        '   ${ratio.toStringAsFixed(1).padLeft(5)}%  '
        '${file.linesHit}/${file.linesFound}  ${file.path}',
      );
    }
    stdout.writeln('');
  }

  if (summary.percent + 1e-9 < threshold) {
    stderr.writeln(
      '🚫 Total coverage $percent% '
      '(${summary.linesHit}/${summary.linesFound} lines) '
      'is below the ${threshold.toStringAsFixed(0)}% minimum.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    '✅ Total coverage $percent% '
    '(${summary.linesHit}/${summary.linesFound} lines) '
    'meets the ${threshold.toStringAsFixed(0)}% minimum.',
  );
}
