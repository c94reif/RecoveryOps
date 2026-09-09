import 'dart:io';

/// Mirrors the `version:` from `pubspec.yaml` into
/// `lib/app/app_version.g.dart` as a `const String appVersion`, so the About
/// screen always shows the real package version without anyone hand-editing it.
///
/// The build number (the `+N` suffix) is dropped — the About screen shows the
/// human-facing semantic version only (e.g. `0.1.0`, not `0.1.0+1`).
///
/// Usage:
///   dart run tool/sync_version.dart           # regenerate the file
///   dart run tool/sync_version.dart --check    # fail if stale (CI / hooks)
void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final version = _readPubspecVersion();
  final generated = _render(version);

  final target = File('lib/app/app_version.g.dart');
  final current = target.existsSync() ? target.readAsStringSync() : null;

  if (checkOnly) {
    if (current != generated) {
      stderr.writeln(
        '🚫 lib/app/app_version.g.dart is out of sync with pubspec.yaml '
        '(version $version).\n'
        '   Run: dart run tool/sync_version.dart  then stage the file.',
      );
      exit(1);
    }
    stdout.writeln('✅ App version in sync ($version).');
    return;
  }

  if (current == generated) {
    stdout.writeln('App version already in sync ($version).');
    return;
  }
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(generated);
  stdout.writeln('Wrote lib/app/app_version.g.dart (version $version).');
}

/// The `version:` value from pubspec.yaml with any `+build` suffix stripped.
String _readPubspecVersion() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('🚫 pubspec.yaml not found.');
    exit(2);
  }
  for (final line in pubspec.readAsLinesSync()) {
    final match = RegExp(r'^version:\s*(\S+)').firstMatch(line);
    if (match != null) {
      return match.group(1)!.split('+').first;
    }
  }
  stderr.writeln('🚫 No `version:` field found in pubspec.yaml.');
  exit(2);
}

/// The full contents of the generated file for [version]. The `--check` mode
/// compares byte-for-byte against this, so keep generation deterministic.
String _render(String version) =>
    '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
    '// Regenerate with: dart run tool/sync_version.dart\n'
    '//\n'
    '// Mirrors the `version:` in pubspec.yaml (build number dropped) so the\n'
    '// About screen always shows the real package version.\n'
    '\n'
    "const String appVersion = '$version';\n";
