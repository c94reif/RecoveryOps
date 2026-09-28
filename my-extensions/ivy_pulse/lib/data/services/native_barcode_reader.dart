import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';

class NativeBarcodeReader {
  static const List<String> formats = ['pdf417', 'code_39'];

  static bool get isSupported =>
      globalContext.hasProperty('BarcodeDetector'.toJS).toDart;

  _BarcodeDetector? _detector;

  _BarcodeDetector get _initializedDetector => _detector ??= _BarcodeDetector(
        _BarcodeDetectorOptions(
          formats: formats.map((format) => format.toJS).toList().toJS,
        ),
      );

  Future<Pdf417Read?> read(web.ImageBitmap bitmap) async {
    try {
      final found = (await _initializedDetector.detect(bitmap).toDart).toDart;
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
    } catch (error) {
      debugPrint('[IvyPulse] native detector unavailable: $error');
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
