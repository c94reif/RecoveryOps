import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';
import 'package:zxing_lib/pdf417.dart';
import 'package:zxing_lib/zxing.dart';
import 'support/cac_fixtures.dart';

void main() {
  test('probe', () {
    const decoder = Pdf417ImageDecoder();
    final matrix = PDF417Writer().encode(
        cacBarcode(), BarcodeFormat.pdf417, 0, 0, const EncodeHint(margin: 0));
    final rnd = Random(7);

    for (final dims in [
      [1600, 1200],
      [2600, 1950]
    ]) {
      for (final scale in [2, 4]) {
        final w = dims[0], h = dims[1];
        final rgba = Uint8List(w * h * 4);
        // noisy mid-grey background, like a photo of a desk
        for (var i = 0; i < w * h; i++) {
          final v = 150 + rnd.nextInt(90);
          rgba[i * 4] = v;
          rgba[i * 4 + 1] = v;
          rgba[i * 4 + 2] = v;
          rgba[i * 4 + 3] = 255;
        }
        final ox = (w - matrix.width * scale) ~/ 2;
        final oy = (h - matrix.height * scale) ~/ 2;
        // white card
        for (var y = oy - 40; y < oy + matrix.height * scale + 40; y++) {
          for (var x = ox - 40; x < ox + matrix.width * scale + 40; x++) {
            final o = (y * w + x) * 4;
            rgba[o] = 245;
            rgba[o + 1] = 245;
            rgba[o + 2] = 245;
          }
        }
        for (var y = 0; y < matrix.height; y++) {
          for (var x = 0; x < matrix.width; x++) {
            if (!matrix.get(x, y)) continue;
            for (var dy = 0; dy < scale; dy++) {
              for (var dx = 0; dx < scale; dx++) {
                final o = ((oy + y * scale + dy) * w + ox + x * scale + dx) * 4;
                rgba[o] = 12;
                rgba[o + 1] = 12;
                rgba[o + 2] = 12;
              }
            }
          }
        }
        final sw = Stopwatch()..start();
        final r = decoder.decodeRgba(rgba, width: w, height: h);
        sw.stop();
        // ignore: avoid_print
        print(
            'PROBE ${w}x$h scale=$scale hit=${r.text != null} ${sw.elapsedMilliseconds}ms');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
