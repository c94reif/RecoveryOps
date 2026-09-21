import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/pdf417.dart';
import 'package:zxing_lib/zxing.dart';

/// What one frame gave up.
///
/// Richer than the bare `String?` this used to hand back, because the ways a
/// decode can miss want different sentences in front of the operator. Telling
/// a Soldier "no barcode found" when the barcode *was* found and was merely
/// smeared sends them hunting the wrong face of the card; telling one who
/// never had it in frame to "hold steady" is noise. The geometry here is what
/// lets the caller tell those apart.
///
/// Everything but [text] is filled in only on a miss. A hit has already
/// answered the question and pays nothing to collect the rest.
class Pdf417Read {
  /// The decoded PDF417 payload, or null if nothing resolved.
  final String? text;

  /// A symbol was in the frame, whether or not its codewords resolved. This
  /// is the line between "aim at something else" and "clean the card".
  final bool located;

  /// Pixels per module of the located symbol's start pattern, when both ends
  /// of it survived detection. The measure of whether the card was simply too
  /// far away to have been readable at any exposure.
  final double? modulePx;

  /// Text off a Code 39 found in the same frame — on a CAC, the wide strip on
  /// the back. Hunted for only when no PDF417 was located at all, and never
  /// interpreted here: what an 18-character string means is `ParseCacBarcode`'s
  /// call, where it is testable without a camera.
  final String? code39Text;

  const Pdf417Read.hit(String this.text)
      : located = true,
        modulePx = null,
        code39Text = null;

  const Pdf417Read.miss({
    this.located = false,
    this.modulePx,
    this.code39Text,
  }) : text = null;
}

/// Reads the PDF417 off a frame of RGBA pixels.
///
/// Pure Dart over an in-memory buffer, so it runs identically under the test
/// VM and in the WebView — nothing in here touches the DOM.
class Pdf417ImageDecoder {
  const Pdf417ImageDecoder();

  /// How many detector sweeps have been run since a test last zeroed this.
  ///
  /// Here because the happy path's cost is a promise this file makes in prose
  /// ("pays for none of what follows it") and prose does not fail a build. The
  /// obvious assertion — that a hit reports no module width — is a tautology:
  /// [Pdf417Read.hit] hardcodes that field null, so it holds just as well
  /// after someone moves the detector sweep in front of the early return and
  /// puts a four-rotation scan on every successful scan. Counting the sweeps
  /// is the only thing that actually notices.
  @visibleForTesting
  static int locateSweeps = 0;

  /// Below this many pixels per module, no amount of light or steadiness will
  /// resolve the symbol and the only instruction worth giving is "get closer".
  ///
  /// Deliberately conservative. A judge measured a correctly framed card at
  /// the first scan width landing right around 2.0 px/module, so a floor of
  /// 2.0 would tell a Soldier who did everything right to move closer — the
  /// one piece of advice guaranteed to make them distrust the next message
  /// too. Erring low costs an occasional "could not read it" where "too
  /// small" was truer; erring high costs the operator's trust. Calibrate
  /// against a real EUD photo using the miss line [decodeRgba] debugPrints.
  static const double minDecodableModulePx = 1.5;

  /// Slack left around a located symbol before cropping to it. PDF417 needs a
  /// quiet zone, and detector vertices sit on the pattern itself.
  static const double _cropPadFraction = 0.04;

  /// Smallest crop worth binarising. Under this there is no symbol left.
  static const int _minCropPx = 16;

  Pdf417Read decodeRgba(
    Uint8List rgba, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return const Pdf417Read.miss();
    }

    final BinaryBitmap bitmap;
    try {
      bitmap = BinaryBitmap(
        HybridBinarizer(
          RGBLuminanceSource.orig(width, height, _luminance(rgba)),
        ),
      );
    } catch (e) {
      debugPrint('[IvyPulse] PDF417 binarise failed: $e');
      return const Pdf417Read.miss();
    }

    // The happy path pays for none of what follows it: one decode, and a
    // clean symbol returns before the detector, the crop or the 1D sweep are
    // ever reached.
    final full = _readPdf417(bitmap);
    final fullText = full.text;
    if (fullText != null) return Pdf417Read.hit(fullText);

    var located = full.located;

    // Nothing resolved across the whole frame. Before reporting anything to
    // the operator, find out where the symbol is and decode that patch alone.
    //
    // The point is the black point. HybridBinarizer derives it from the frame
    // it is given, and a frame that is four fifths card stock, hand and sky
    // sets it far too high for the two square centimetres that matter. A crop
    // re-derives it from the barcode. This recovers symbols the full frame
    // misses with the operator doing nothing at all, which makes it worth
    // more than every message below it. Cheaper than it looks, too: the
    // binarised matrix of the full frame is already cached on [bitmap], so
    // the extra detection sweep is vertex-finding, not re-binarising.
    final symbol = _locate(bitmap);
    if (symbol != null) {
      located = true;
      final box = symbol.crop;
      if (box != null && bitmap.isCropSupported) {
        try {
          final retry = _readPdf417(
            bitmap.crop(box.left, box.top, box.width, box.height),
          );
          final retryText = retry.text;
          if (retryText != null) return Pdf417Read.hit(retryText);
        } catch (e) {
          debugPrint('[IvyPulse] PDF417 crop retry failed: $e');
        }
      }
    }

    // The only calibration mechanism there is for [minDecodableModulePx].
    // Run a real EUD photo through, read this line, set the floor under what
    // a readable card actually measures.
    debugPrint(
      '[IvyPulse] PDF417 miss: located=$located '
      'modulePx=${symbol?.modulePx?.toStringAsFixed(2)} frame=${width}x$height',
    );

    // Worth sweeping for the gate strip only when no PDF417 was anywhere in
    // the frame. If one was located, the operator already has the right face
    // of the card pointed at the camera and telling them to turn it over is
    // the worst thing this file could say.
    final code39 = located ? null : _readCode39(bitmap);

    return Pdf417Read.miss(
      located: located,
      modulePx: symbol?.modulePx,
      code39Text: code39,
    );
  }

  /// One PDF417 pass, with the miss classified by exception type.
  ///
  /// That classification is free, which is the whole reason it is done this
  /// way. `PDF417Reader.decode` does not normalise its exceptions the way
  /// `decodeMultiple` does, so a ChecksumException or FormatsException means
  /// the symbol was located and its codewords would not resolve, while a
  /// NotFoundException means the detector never saw one. Any other way of
  /// telling those apart costs a second sweep over the frame.
  ({String? text, bool located}) _readPdf417(BinaryBitmap bitmap) {
    try {
      // No DecodeHint on purpose. `tryHarder` is a dead letter for PDF417 —
      // the detector's only reference to it is a commented-out TODO — so
      // passing it buys nothing while reading as though it buys something.
      // It is emphatically alive for the 1D sweep in [_readCode39], which is
      // why that one still sets it.
      return (text: PDF417Reader().decode(bitmap).text, located: true);
    } on ChecksumException catch (_) {
      return (text: null, located: true);
    } on FormatsException catch (_) {
      return (text: null, located: true);
    } on NotFoundException catch (_) {
      return (text: null, located: false);
    } catch (e) {
      debugPrint('[IvyPulse] PDF417 decode miss: $e');
      return (text: null, located: false);
    }
  }

  /// Finds where the symbol is and how big its modules are, without decoding.
  ///
  /// Returns null when nothing was located. Note that `Detector.detect` does
  /// not throw on an empty frame — it hands back a result with no barcodes in
  /// it — so the emptiness has to be checked rather than caught.
  _LocatedSymbol? _locate(BinaryBitmap bitmap) {
    locateSweeps++;

    final PDF417DetectorResult detection;
    try {
      detection = Detector.detect(bitmap, null, false);
    } catch (e) {
      debugPrint('[IvyPulse] PDF417 locate failed: $e');
      return null;
    }
    if (detection.points.isEmpty) return null;

    // A list of BARCODES, each an eight-vertex array whose entries are every
    // one of them nullable — a symbol detected from its stop pattern alone
    // comes back with no start vertices, which is precisely the damaged card
    // this branch exists for. Never `!` one of these.
    final vertices = detection.points.first;

    final start = vertices.isNotEmpty ? vertices[0] : null;
    final startEnd = vertices.length > 4 ? vertices[4] : null;

    double? modulePx;
    if (start != null && startEnd != null) {
      // Indices 0 and 4 are the two ends of the start pattern, which is
      // exactly PDF417Common.modulesInCodeword modules wide by definition, so
      // this is a measurement rather than an estimate. Rotation is a right
      // angle, so the span survives it and needs no unmapping.
      final span = (startEnd.x - start.x).abs();
      if (span > 0) modulePx = span / PDF417Common.modulesInCodeword;
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var seen = 0;
    for (final vertex in vertices) {
      if (vertex == null) continue;
      final (x, y) = _unrotate(
        vertex,
        detection.rotation,
        bitmap.width,
        bitmap.height,
      );
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      seen++;
    }
    if (seen < 2) return _LocatedSymbol(modulePx: modulePx);

    // One pad off the longer edge rather than a fraction of each axis: a
    // CAC's symbol is about twice as tall as it is wide, and 4% of its width
    // is less quiet zone than the detector wants beside the start pattern.
    final pad = math.max(
      math.max(maxX - minX, maxY - minY) * _cropPadFraction,
      4.0,
    );

    final left = math.max(0, (minX - pad).floor());
    final top = math.max(0, (minY - pad).floor());
    final right = math.min(bitmap.width, (maxX + pad).ceil());
    final bottom = math.min(bitmap.height, (maxY + pad).ceil());
    final cropWidth = right - left;
    final cropHeight = bottom - top;

    // Degenerate, and `RGBLuminanceSource.crop` throws on a rectangle that
    // does not fit rather than clamping, so this guard is load-bearing.
    if (cropWidth < _minCropPx || cropHeight < _minCropPx) {
      return _LocatedSymbol(modulePx: modulePx);
    }
    // Nearly the whole frame already: re-binarising it derives the same black
    // point and buys the same miss for the same money.
    if (cropWidth >= bitmap.width * 0.95 && cropHeight >= bitmap.height * 0.95) {
      return _LocatedSymbol(modulePx: modulePx);
    }

    return _LocatedSymbol(
      modulePx: modulePx,
      crop: _CropBox(left, top, cropWidth, cropHeight),
    );
  }

  /// Hunts for a CAC's own Code 39 — the wide strip on the back, the face a
  /// Soldier is trained to show a gate sentry and so the face they reach for
  /// first. Finding it is the difference between "no barcode found" and the
  /// one instruction that fixes the problem.
  ///
  /// `tryHarder` earns its keep here, unlike on the PDF417 path: it makes
  /// OneDReader walk every row of the frame instead of fifteen around the
  /// middle. It will not find a strip running UP the frame — RGBLuminanceSource
  /// cannot rotate, so OneDReader's rotated retry never fires — but the strip
  /// runs along the long edge of a landscape-printed back, so a card held the
  /// way anyone holds a card reads. A miss falls through to the ordinary "no
  /// barcode found", which is the honest answer anyway.
  String? _readCode39(BinaryBitmap bitmap) {
    try {
      return Code39Reader()
          .decode(bitmap, const DecodeHint(tryHarder: true))
          .text;
    } on NotFoundException catch (_) {
      // No strip in the frame. The ordinary case, not an error.
      return null;
    } on FormatsException catch (_) {
      return null;
    } on ChecksumException catch (_) {
      return null;
    } catch (e) {
      debugPrint('[IvyPulse] Code 39 sweep failed: $e');
      return null;
    }
  }

  /// Maps a detector vertex back into the frame that was handed in.
  ///
  /// `Detector.detect` sweeps four rotations and returns coordinates in
  /// whichever rotated copy it found the symbol in — and on a CAC that is
  /// hardly ever rotation 0, because the PDF417's long axis runs up the
  /// portrait card while the phone frame is landscape. Cropping the original
  /// bitmap with those coordinates left unmapped crops a corner of sky and
  /// turns a hit into a miss. [width] and [height] are the frame's, not the
  /// rotated copy's.
  static (double, double) _unrotate(
    ResultPoint point,
    int rotation,
    int width,
    int height,
  ) {
    switch (rotation % 360) {
      // BitMatrix.rotate90 sends (x, y) to (y, width - 1 - x).
      case 90:
        return (width - 1 - point.y, point.x);
      case 180:
        return (width - 1 - point.x, height - 1 - point.y);
      // 270 is rotate90 followed by rotate180, which lands (x, y) on
      // (height - 1 - y, x).
      case 270:
        return (point.y, height - 1 - point.x);
      default:
        return (point.x, point.y);
    }
  }

  static Uint8List _luminance(Uint8List rgba) {
    final pixels = rgba.length ~/ 4;
    final out = Uint8List(pixels);
    for (var i = 0; i < pixels; i++) {
      final o = i * 4;
      out[i] = (rgba[o] + (rgba[o + 1] << 1) + rgba[o + 2]) >> 2;
    }
    return out;
  }
}

/// Where a symbol is in the frame and how coarsely it was rendered. [crop] is
/// null when the symbol was located but there is no useful rectangle to retry
/// on — a sliver, or the whole frame over again.
class _LocatedSymbol {
  final double? modulePx;
  final _CropBox? crop;

  const _LocatedSymbol({this.modulePx, this.crop});
}

class _CropBox {
  final int left;
  final int top;
  final int width;
  final int height;

  const _CropBox(this.left, this.top, this.width, this.height);
}
