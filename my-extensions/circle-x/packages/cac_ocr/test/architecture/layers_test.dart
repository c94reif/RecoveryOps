import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
const _portableDart = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:math'
};
const _src = 'package:cac_ocr/src/';

List<File> _dartFiles(String path) => FileSystemEntity.isFileSync(path)
    ? [File(path)]
    : Directory(path)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

/// Every directive under [paths] that reaches outside portable Dart and the
/// [allowed] package paths.
List<String> reachesOutside(List<String> paths, List<String> allowed) => [
      for (final path in paths)
        for (final file in _dartFiles(path))
          for (final match in _directive.allMatches(file.readAsStringSync()))
            if (!_portableDart.contains(match.group(1)) &&
                !allowed.any(match.group(1)!.startsWith))
              '${file.path}: ${match.group(1)}',
    ];

/// Every directive under [paths] into one of the [forbidden] package paths.
List<String> reachesInto(List<String> paths, List<String> forbidden) => [
      for (final path in paths)
        for (final file in _dartFiles(path))
          for (final match in _directive.allMatches(file.readAsStringSync()))
            if (forbidden.any(match.group(1)!.startsWith))
              '${file.path}: ${match.group(1)}',
    ];

void main() {
  // An app's domain layer imports cac_core.dart, so one Flutter import here
  // would drag the framework into every layer that trusts it not to.
  test('the domain needs nothing but Dart and itself', () {
    expect(reachesOutside(['lib/src/domain'], ['${_src}domain/']), isEmpty);
  });

  test('the application layer adds use cases and ports, still plain Dart', () {
    expect(
      reachesOutside(['lib/cac_core.dart', 'lib/src/application'],
          ['${_src}domain/', '${_src}application/']),
      isEmpty,
    );
  });

  test('scanners never reach into the UI', () {
    expect(reachesInto(['lib/src/infrastructure'], ['${_src}presentation/']),
        isEmpty);
  });

  // ML Kit imports dart:io, so a widget that named a platform scanner would
  // break the web build; widgets see scanners only through their contracts.
  test('the UI knows no platform scanner', () {
    expect(
      reachesInto([
        'lib/src/presentation'
      ], [
        '${_src}infrastructure/android/',
        '${_src}infrastructure/web/',
        'package:google_mlkit',
      ]),
      isEmpty,
    );
  });

  test('the testing library runs in a plain Dart test as well', () {
    expect(
      reachesOutside([
        'lib/testing.dart',
        'lib/src/testing'
      ], [
        '${_src}domain/',
        '${_src}application/',
        '${_src}testing/',
      ]),
      isEmpty,
    );
  });
}
