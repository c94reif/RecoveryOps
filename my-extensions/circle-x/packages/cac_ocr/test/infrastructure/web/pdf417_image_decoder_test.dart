import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/infrastructure/web/pdf417_image_decoder.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/pdf417.dart';
import 'package:zxing_lib/zxing.dart';

import 'package:cac_ocr/testing.dart';

class Frame {
  final int width;
  final int height;
  final Uint8List rgba;

  Frame(this.width, this.height)
      : rgba = Uint8List(width * height * 4)
          ..fillRange(0, width * height * 4, 0xFF);

  void paint(BitMatrix matrix,
      {required int x, required int y, int scale = 3}) {
    for (var my = 0; my < matrix.height; my++) {
      for (var mx = 0; mx < matrix.width; mx++) {
        if (!matrix.get(mx, my)) continue;
        fill(
          x + mx * scale,
          y + my * scale,
          scale,
          scale,
          0,
        );
      }
    }
  }

  void fill(int left, int top, int w, int h, int value) {
    for (var py = top; py < top + h; py++) {
      if (py < 0 || py >= height) continue;
      for (var px = left; px < left + w; px++) {
        if (px < 0 || px >= width) continue;
        final o = (py * width + px) * 4;
        rgba[o] = value;
        rgba[o + 1] = value;
        rgba[o + 2] = value;
      }
    }
  }

  Pdf417Read read() =>
      const Pdf417ImageDecoder().decodeRgba(rgba, width: width, height: height);
}

BitMatrix pdf417Of(String contents) => PDF417Writer()
    .encode(contents, BarcodeFormat.pdf417, 0, 0, const EncodeHint(margin: 0));

BitMatrix code39Of(String contents) => Code39Writer()
    .encode(contents, BarcodeFormat.code39, 0, 1, const EncodeHint(margin: 0));

void main() {
  final record = cacBarcode();

  test('the fixture is the record the front of a CAC actually carries', () {
    expect(record.length, 89,
        reason: 'the front of a CAC is an 89-character version-N record');
  });

  group('a clean read', () {
    test('answers with the text and nothing else', () {
      final symbol = pdf417Of(record);
      final frame = Frame(symbol.width * 3 + 48, symbol.height * 3 + 48)
        ..paint(symbol, x: 24, y: 24);

      final read = frame.read();

      expect(read.text, record);
      expect(read.located, isTrue);
      expect(read.code39Text, isNull);
    });
  });

  group('a symbol that was found but would not resolve', () {
    Frame damaged({int scale = 3}) {
      final symbol = pdf417Of(record);
      final frame = Frame(
        symbol.width * scale + 48,
        symbol.height * scale + 48,
      )..paint(symbol, x: 24, y: 24, scale: scale);

      frame.fill(
        24 + (symbol.width * scale * 0.25).round(),
        24,
        (symbol.width * scale * 0.5).round(),
        symbol.height * scale,
        0xFF,
      );
      return frame;
    }

    test('is reported as located, not as nothing found', () {
      final read = damaged().read();

      expect(read.text, isNull);
      expect(read.located, isTrue);
    });

    test('carries the module width it measured', () {
      final read = damaged(scale: 3).read();

      expect(read.modulePx, isNotNull);
      expect(read.modulePx, closeTo(3.0, 0.35));
    });

    test('the module width tracks the size the card was shot at', () {
      final small = damaged(scale: 2).read();
      final large = damaged(scale: 5).read();

      expect(small.modulePx, closeTo(2.0, 0.35));
      expect(large.modulePx, closeTo(5.0, 0.5));
      expect(small.modulePx!, lessThan(large.modulePx!));
    });

    test('a symbol shot below the decodable floor measures below it', () {
      final read = damaged(scale: 1).read();

      expect(read.located, isTrue);
      expect(read.modulePx, lessThan(Pdf417ImageDecoder.minDecodableModulePx));
      expect(damaged(scale: 2).read().modulePx,
          greaterThanOrEqualTo(Pdf417ImageDecoder.minDecodableModulePx),
          reason: 'a card framed the way the operator was told to frame it '
              'must not be called too small');
    });

    test('no Code 39 sweep is run once a PDF417 has been located', () {
      final strip = code39Of('1TPBOMMS10DINPAEDL');

      void paintStrip(Frame target) {
        for (var mx = 0; mx < strip.width; mx++) {
          if (!strip.get(mx, 0)) continue;
          target.fill(20 + mx * 2, target.height - 70, 2, 50, 0);
        }
      }

      final control = damaged();
      final stripOnly = Frame(control.width, control.height);
      paintStrip(stripOnly);
      expect(stripOnly.read().code39Text, '1TPBOMMS10DINPAEDL',
          reason: 'the control frame must prove the strip is readable here');

      final frame = damaged();
      paintStrip(frame);
      final read = frame.read();

      expect(read.located, isTrue);
      expect(read.code39Text, isNull);
    });
  });

  group('the wrong side of the card', () {
    test('a Code 39 in the frame comes back as Code 39 text', () {
      final strip = code39Of('1TPBOMMS10DINPAEDL');
      final frame = Frame(strip.width * 2 + 80, 160)
        ..paint(strip, x: 40, y: 40, scale: 2);
      frame.fill(0, 0, frame.width, frame.height, 0xFF);
      for (var my = 0; my < strip.width; my++) {
        if (!strip.get(my, 0)) continue;
        frame.fill(40 + my * 2, 40, 2, 80, 0);
      }

      final read = frame.read();

      expect(read.text, isNull);
      expect(read.located, isFalse);
      expect(read.code39Text, '1TPBOMMS10DINPAEDL',
          reason: 'the strip is handed up verbatim — what an 18-character '
              'string means is ParseCacBarcode\'s call, not this file\'s');
    });

    test('an empty frame finds neither barcode and does not crash', () {
      final read = Frame(200, 200).read();

      expect(read.text, isNull);
      expect(read.located, isFalse);
      expect(read.code39Text, isNull);
      expect(read.modulePx, isNull);
    });
  });

  group('a card small in a big frame', () {
    test('the happy path never goes through the detector', () {
      Pdf417ImageDecoder.locateSweeps = 0;

      final symbol = pdf417Of(record);
      final frame = Frame(symbol.width * 3 + 48, symbol.height * 3 + 48)
        ..paint(symbol, x: 24, y: 24);

      final read = frame.read();

      expect(read.text, record);
      expect(Pdf417ImageDecoder.locateSweeps, 0,
          reason: 'a clean read must return before the detector, the crop and '
              'the 1D sweep are ever reached');

      Pdf417ImageDecoder.locateSweeps = 0;
      Frame(200, 200).read();
      expect(Pdf417ImageDecoder.locateSweeps, 1);
    });

    test('a symbol at a fraction of a 1600px frame still reads', () {
      final symbol = pdf417Of(record);
      final frame = Frame(1600, 1200);
      frame.fill(0, 0, 1600, 1200, 0x9A);
      frame.fill(560, 380, symbol.width * 2 + 80, symbol.height * 2 + 80, 0xF2);
      frame.paint(symbol, x: 600, y: 420, scale: 2);

      expect(frame.read().text, record,
          reason: 'the symbol is about a fifth of the frame width — the size '
              'a card held at arm\'s length lands at');
    });

    test('a symbol hard against the frame edge is refused, not thrown', () {
      final symbol = pdf417Of(record);
      final frame = Frame(symbol.width * 3, symbol.height * 3)
        ..paint(symbol, x: 0, y: 0);
      frame.fill(
        (symbol.width * 3 * 0.25).round(),
        0,
        (symbol.width * 3 * 0.5).round(),
        symbol.height * 3,
        0xFF,
      );

      late Pdf417Read read;
      expect(() => read = frame.read(), returnsNormally);
      expect(read.located, isTrue);
      expect(read.text, isNull);
    });
  });

  group('frames that are not frames', () {
    test('a truncated buffer is refused rather than read past', () {
      const decoder = Pdf417ImageDecoder();

      expect(decoder.decodeRgba(Uint8List(16), width: 200, height: 200).located,
          isFalse);
    });

    test('a zero-sized frame is refused', () {
      const decoder = Pdf417ImageDecoder();
      final read = decoder.decodeRgba(Uint8List(0), width: 0, height: 0);

      expect(read.text, isNull);
      expect(read.located, isFalse);
    });
  });
}
