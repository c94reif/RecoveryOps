/// Parses `lcov.info` coverage data and summarizes line coverage for the
/// project's 80% coverage rule (see CLAUDE.md).
///
/// Generated files are excluded from the totals so the floor reflects
/// hand-written components only.
library;

import 'dart:convert';

import 'generated_files.dart';

/// The minimum acceptable line-coverage percentage for the project.
const double minimumCoveragePercent = 80.0;

/// Line-coverage tally for a single source file.
typedef FileCoverage = ({String path, int linesFound, int linesHit});

/// Aggregate line-coverage tally across a set of files.
typedef CoverageSummary = ({int linesFound, int linesHit, double percent});

/// Parses [lcov] content into one [FileCoverage] entry per `SF:` record.
///
/// Line counts are derived from `DA:<line>,<hits>` entries so the result does
/// not depend on the optional `LF:`/`LH:` summary lines being present.
List<FileCoverage> parseLcov(String lcov) {
  final coverages = <FileCoverage>[];

  String? currentPath;
  var linesFound = 0;
  var linesHit = 0;

  for (final rawLine in const LineSplitter().convert(lcov)) {
    final line = rawLine.trim();

    if (line.startsWith('SF:')) {
      currentPath = line.substring(3);
      linesFound = 0;
      linesHit = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        linesFound++;
        final hits = int.tryParse(parts[1]) ?? 0;
        if (hits > 0) linesHit++;
      }
    } else if (line == 'end_of_record' && currentPath != null) {
      coverages.add((
        path: currentPath,
        linesFound: linesFound,
        linesHit: linesHit,
      ));
      currentPath = null;
    }
  }

  return coverages;
}

/// Computes the aggregate coverage across [files], skipping generated files.
///
/// [percent] is 100.0 when no coverable lines remain, avoiding a divide by
/// zero for empty or fully-generated inputs.
CoverageSummary summarize(List<FileCoverage> files) {
  var linesFound = 0;
  var linesHit = 0;

  for (final file in files) {
    if (isGeneratedDartFile(file.path)) continue;
    linesFound += file.linesFound;
    linesHit += file.linesHit;
  }

  final percent = linesFound == 0 ? 100.0 : (linesHit / linesFound) * 100;
  return (linesFound: linesFound, linesHit: linesHit, percent: percent);
}

/// Returns the non-generated files whose coverage is below [threshold],
/// ordered from least to most covered.
List<FileCoverage> filesBelowThreshold(
  List<FileCoverage> files, {
  double threshold = minimumCoveragePercent,
}) {
  double ratio(FileCoverage file) =>
      file.linesFound == 0 ? 100.0 : (file.linesHit / file.linesFound) * 100;

  final below = files
      .where((file) => !isGeneratedDartFile(file.path))
      .where((file) => file.linesFound > 0 && ratio(file) < threshold)
      .toList()
    ..sort((a, b) => ratio(a).compareTo(ratio(b)));

  return below;
}
