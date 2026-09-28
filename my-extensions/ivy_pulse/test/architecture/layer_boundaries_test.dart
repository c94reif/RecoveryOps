import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<(String, String)> dependencies(String directory) sync* {
  final directive = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  for (final file in Directory(directory).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final match in directive.allMatches(file.readAsStringSync())) {
      yield (file.path, match.group(1)!);
    }
  }
}

void main() {
  test('domain depends only on domain types and portable Dart libraries', () {
    final forbidden = dependencies('lib/domain').where((dependency) {
      final (_, uri) = dependency;
      return !uri.startsWith('package:ivy_pulse/domain/') &&
          !uri.startsWith('package:characters/') &&
          !uri.startsWith('package:latlong2/') &&
          !{'dart:async', 'dart:convert', 'dart:math', 'dart:collection'}
              .contains(uri);
    });
    expect(forbidden, isEmpty);
  });

  test('data implementations do not depend on presentation', () {
    expect(
      dependencies('lib/data').where((dependency) =>
          dependency.$2.startsWith('package:ivy_pulse/presentation/')),
      isEmpty,
    );
  });

  test('presentation uses domain ports instead of data implementations', () {
    expect(
      dependencies('lib/presentation').where((dependency) =>
          dependency.$2.startsWith('package:ivy_pulse/data/') ||
          dependency.$2 == 'package:ivy_pulse/core/di/injection.dart' ||
          dependency.$2.startsWith('package:le_sdk/')),
      isEmpty,
    );
  });
}
