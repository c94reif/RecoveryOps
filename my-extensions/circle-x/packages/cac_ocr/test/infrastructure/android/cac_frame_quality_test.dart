import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_quality.dart';

void main() {
  const width = 64;
  const height = 48;

  Uint8List plane(int Function(int x, int y) shade) => Uint8List.fromList([
        for (var y = 0; y < height; y++)
          for (var x = 0; x < width; x++) shade(x, y),
      ]);

  final crisp = plane((x, y) => (x ~/ 4 + y ~/ 4).isEven ? 200 : 0);
  final soft = plane((x, y) => 100 + ((x + y) % 8));
  final flat = plane((x, y) => 120);

  test('crisp edges score higher than soft ones, and flat scores nothing', () {
    final sharp = measureCacFrame(crisp, width, height).sharpness;
    final blurred = measureCacFrame(soft, width, height).sharpness;

    expect(sharp, greaterThan(blurred * 10));
    expect(measureCacFrame(flat, width, height).sharpness, 0);
  });

  test('glare is the share of the frame washed out to white', () {
    final half = plane((x, y) => y < height ~/ 2 ? 255 : 90);

    expect(measureCacFrame(crisp, width, height).glare, 0);
    expect(measureCacFrame(half, width, height).glare, closeTo(0.5, 0.1));
    expect(measureCacFrame(plane((x, y) => 255), width, height).glare, 1.0);
  });

  test('a frame too small to sample measures nothing rather than throwing', () {
    final tiny = measureCacFrame(Uint8List(16), 4, 4);

    expect(tiny.sharpness, 0);
    expect(tiny.glare, 0);
  });
}
