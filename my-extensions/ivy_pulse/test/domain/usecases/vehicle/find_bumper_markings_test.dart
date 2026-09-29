import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/usecases/vehicle/find_bumper_markings.dart';

void main() {
  test('keeps unit markings and bumper choices separate and removes duplicates',
      () {
    expect(findBumperMarkings(['4ID  1-8IN', 'a - 11', 'A-11', ' HQ–66 ']),
        ['4ID 1-8IN', 'A-11', 'HQ-66']);
  });

  test('retains separated stencil letters and numbers for manual selection',
      () {
    expect(findBumperMarkings(['A', '11', 'B 22', '42', 'HQ']),
        ['A', '11', 'B 22', '42', 'HQ']);
  });

  test('does not guess at commonly confused characters or invent a format', () {
    expect(findBumperMarkings(['B-O1', 'B-01', 'I-11', '1-11', 'HQ/6', 'A.12']),
        ['B-O1', 'B-01', 'I-11', '1-11', 'HQ/6', 'A.12']);
  });

  test('ignores blank or unusable OCR instead of stripping random symbols', () {
    expect(findBumperMarkings(['', '   ', '@@@', '---', 'B#12', 'A' * 65]),
        isEmpty);
  });
}
