import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';

/// The browser's own barcode detector, where the WebView ships one.
///
/// Android's WebView backs `BarcodeDetector` with ML Kit, and on the host
/// this extension runs in it advertises `pdf417` and `code_39` among its
/// formats. That detector is the same engine a phone's camera app uses to
/// read a code off a live preview: it finds the symbol anywhere in the frame
/// at any angle, tolerates the perspective and glare a hand-held shot of a
/// card always has, and does it in native code in a few tens of
/// milliseconds. The pure-Dart decoder behind [Pdf417ImageDecoder] is the
/// same job done by hand on a downscaled copy, and it is the half of the
/// pipeline that used to decide whether a scan succeeded.
///
/// So it goes first, and the Dart decoder becomes the fallback — for a
/// WebView that has no detector, and for the frame the native one somehow
/// misses. Nothing about what the operator is asked to do changes: they take
/// the same photo. What changes is how often that photo reads.
///
/// Speaks [Pdf417Read] rather than its own result type so the scanner does
/// not have to know which engine answered. A PDF417 hit is a hit; a Code 39
/// hit is the back of the card, reported exactly the way the Dart decoder
/// reports it, so the wrong-side advice still fires.
class NativeBarcodeReader {
  /// Formats asked for. Code 39 is included on purpose: without it a photo of
  /// the back of the card would come back empty here and fall through to the
  /// Dart passes, which would then find the strip and say so — correct, but
  /// slower than letting the native detector say so at once.
  static const List<String> formats = ['pdf417', 'code_39'];

  /// True where `window.BarcodeDetector` exists at all. Not a promise that it
  /// reads PDF417 — desktop Chrome, for one, ships the API with an empty
  /// format list — which is why [read] also swallows a detector that turns
  /// out to be useless rather than treating it as a decode failure.
  static bool get isSupported =>
      globalContext.hasProperty('BarcodeDetector'.toJS).toDart;

  _BarcodeDetector? _detector;

  _BarcodeDetector get _ready => _detector ??= _BarcodeDetector(
        _BarcodeDetectorOptions(
          formats: formats.map((f) => f.toJS).toList().toJS,
        ),
      );

  /// The frame's answer, or null when the native detector has no opinion —
  /// found nothing, threw, or is not there. Null means "ask the Dart
  /// decoder", never "the frame is empty": only the fallback gets to say
  /// that, because only it measures the geometry the operator's advice is
  /// built from.
  Future<Pdf417Read?> read(web.ImageBitmap bitmap) async {
    try {
      final found = (await _ready.detect(bitmap).toDart).toDart;
      for (final barcode in found) {
        final value = barcode.rawValue;
        if (value.isEmpty) continue;
        switch (barcode.format) {
          case 'pdf417':
            debugPrint('[IvyPulse] CAC read by the native detector');
            return Pdf417Read.hit(value);
          case 'code_39':
            debugPrint('[IvyPulse] native detector saw the back of the card');
            return Pdf417Read.miss(code39Text: value);
        }
      }
      return null;
    } catch (e) {
      // An unsupported format, a detector that refuses ImageBitmap, or a
      // frame it chokes on — all reasons to try the Dart decoder, none of
      // them reasons to tell the operator anything.
      debugPrint('[IvyPulse] native detector unavailable: $e');
      return null;
    }
  }
}

@JS('BarcodeDetector')
extension type _BarcodeDetector._(JSObject _) implements JSObject {
  external factory _BarcodeDetector([_BarcodeDetectorOptions options]);

  external JSPromise<JSArray<_DetectedBarcode>> detect(JSAny image);
}

extension type _BarcodeDetectorOptions._(JSObject _) implements JSObject {
  external factory _BarcodeDetectorOptions({JSArray<JSString> formats});
}

extension type _DetectedBarcode._(JSObject _) implements JSObject {
  external String get rawValue;
  external String get format;
}
