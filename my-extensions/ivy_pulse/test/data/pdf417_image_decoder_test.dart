import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/pdf417.dart';
import 'package:zxing_lib/zxing.dart';

import '../support/cac_fixtures.dart';

/// One RGBA frame, built the way a camera hands one over: white, with black
/// bars painted into it.
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
    // Everything below reads this string back out of pixels, so a fixture
    // that had drifted would make every assertion here agree with a bug.
    expect(record.length, 89,
        reason: 'the front of a CAC is an 89-character version-N record');
  });

  group('a clean read', () {
    test('answers with the text and nothing else', () {
      // The happy path must pay for none of the geometry below it: one
      // decode, and a clean symbol returns before the detector, the crop or
      // the 1D sweep are ever reached.
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
    /// A symbol with a band gouged out of its middle: the start and stop
    /// patterns down the sides survive, so the detector still finds it, but
    /// the codewords in between are gone. This is glare across the card, a
    /// crease, or a thumb over one corner.
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
      // The whole reason [Pdf417Read.located] exists. Telling a Soldier who
      // already has the barcode in frame that no barcode was found sends them
      // hunting the wrong face of the card; telling them to wipe it and hold
      // steady is the instruction that works.
      final read = damaged().read();

      expect(read.text, isNull);
      expect(read.located, isTrue);
    });

    test('carries the module width it measured', () {
      // Only ever filled in on a miss — a hit has already answered the
      // question. This is the number `cardTooSmall` is judged on.
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
      // The floor is deliberately conservative: a correctly framed card at the
      // first scan width lands around 2.0 px/module, so anything near that
      // must NOT read as "too small". Only a genuinely tiny symbol does.
      final read = damaged(scale: 1).read();

      expect(read.located, isTrue);
      expect(read.modulePx, lessThan(Pdf417ImageDecoder.minDecodableModulePx));
      expect(damaged(scale: 2).read().modulePx,
          greaterThanOrEqualTo(Pdf417ImageDecoder.minDecodableModulePx),
          reason: 'a card framed the way the operator was told to frame it '
              'must not be called too small');
    });

    test('no Code 39 sweep is run once a PDF417 has been located', () {
      // Telling an operator who already has the front aimed at the camera to
      // turn the card over is the worst thing this file could say.
      //
      // The frame has to actually CONTAIN a readable Code 39 for this to mean
      // anything. Asserting on a frame that holds only a damaged PDF417 passes
      // whether the gate is there or not, which is how it read before: remove
      // `located ? null :` from the sweep and a fixture with no strip in it
      // still comes back with no strip text.
      final strip = code39Of('1TPBOMMS10DINPAEDL');

      void paintStrip(Frame target) {
        for (var mx = 0; mx < strip.width; mx++) {
          if (!strip.get(mx, 0)) continue;
          target.fill(20 + mx * 2, target.height - 70, 2, 50, 0);
        }
      }

      // The strip has to be decodable in a frame this size on its own, or the
      // real assertion below is vacuous again for a different reason.
      final control = damaged();
      final stripOnly = Frame(control.width, control.height);
      paintStrip(stripOnly);
      expect(stripOnly.read().code39Text, '1TPBOMMS10DINPAEDL',
          reason: 'the control frame must prove the strip is readable here');

      // Same strip, now sharing the frame with a located-but-unreadable
      // PDF417. The gate is the only reason it should not come back.
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
      // Code39Writer emits a one-module-tall matrix, so the bars have to be
      // given height the way the printed strip has it.
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
    // The shape crop-and-retry exists for, and the limit of what this suite
    // can prove about it. A synthetic frame cannot be made to need the crop:
    // HybridBinarizer thresholds per 8x8 block, so the global black point the
    // crop re-derives is not what decides these frames. Swept across two
    // frame sizes, two symbol scales, four bar/space contrasts and four
    // distractor grounds, every frame either decoded full-frame or was not
    // located at all — and a frame with nothing located has no box to crop
    // to. The recovery the crop was built from came off a real EUD photo.
    //
    // What is pinned here instead is everything around it that a change could
    // break silently: the happy path not paying for the detector, the
    // geometry surviving a symbol jammed against the frame edge, and a small
    // symbol on a grey ground still reading.

    test('the happy path never goes through the detector', () {
      // Counted, not inferred. Asserting `modulePx` is null proves nothing —
      // [Pdf417Read.hit] hardcodes that field, so the old version of this test
      // passed just as well with a full four-rotation detector sweep moved in
      // front of the early return.
      Pdf417ImageDecoder.locateSweeps = 0;

      final symbol = pdf417Of(record);
      final frame = Frame(symbol.width * 3 + 48, symbol.height * 3 + 48)
        ..paint(symbol, x: 24, y: 24);

      final read = frame.read();

      expect(read.text, record);
      expect(Pdf417ImageDecoder.locateSweeps, 0,
          reason: 'a clean read must return before the detector, the crop and '
              'the 1D sweep are ever reached');

      // And the miss path really does sweep — otherwise a counter stuck at
      // zero would satisfy the assertion above for the wrong reason.
      Pdf417ImageDecoder.locateSweeps = 0;
      Frame(200, 200).read();
      expect(Pdf417ImageDecoder.locateSweeps, 1);
    });

    test('a symbol at a fraction of a 1600px frame still reads', () {
      final symbol = pdf417Of(record);
      final frame = Frame(1600, 1200);
      // A grey ground and a lighter card, so the black point is not derived
      // from the barcode alone.
      frame.fill(0, 0, 1600, 1200, 0x9A);
      frame.fill(560, 380, symbol.width * 2 + 80, symbol.height * 2 + 80, 0xF2);
      frame.paint(symbol, x: 600, y: 420, scale: 2);

      expect(frame.read().text, record,
          reason: 'the symbol is about a fifth of the frame width — the size '
              'a card held at arm\'s length lands at');
    });

    test('a symbol hard against the frame edge is refused, not thrown', () {
      // RGBLuminanceSource.crop throws ArgumentError on a rectangle that does
      // not fit rather than clamping it, so a symbol detected with no quiet
      // zone left to pad into is the case that would surface as a crash in
      // front of the operator rather than as an instruction.
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
