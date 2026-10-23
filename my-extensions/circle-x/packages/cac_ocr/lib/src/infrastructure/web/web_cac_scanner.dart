import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:cac_ocr/src/infrastructure/web/native_barcode_reader.dart';
import 'package:cac_ocr/src/infrastructure/web/pdf417_image_decoder.dart';
import 'package:cac_ocr/src/infrastructure/web/web_photo_picker.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

class WebCacScanner implements CacScannerStrategy {
  final WebPhotoPicker picker;
  final Pdf417ImageDecoder decoder;

  final NativeBarcodeReader? nativeReader;

  final Duration captureTimeout;

  WebCacScanner({
    WebPhotoPicker? picker,
    this.decoder = const Pdf417ImageDecoder(),
    NativeBarcodeReader? nativeReader,
    bool useNativeReader = true,
    this.captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
  })  : picker = picker ?? WebPhotoPicker(),
        nativeReader = nativeReader ??
            (useNativeReader && NativeBarcodeReader.isSupported
                ? NativeBarcodeReader()
                : null);

  static const List<int> scanWidths = [1600, 2600, 1000];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> cancel() async => picker.cancel();

  @override
  Future<CacCapture> capture() async {
    final ({web.File? photo, bool timedOut}) captureResult;
    try {
      captureResult = await picker.take(timeout: captureTimeout);
    } catch (error) {
      debugPrint('[CacOcr] CAC capture failed: $error');
      return const CacCapture.failed(CacRejection.noCamera);
    }
    if (captureResult.timedOut) {
      return const CacCapture.failed(CacRejection.cameraTimedOut);
    }
    final photo = captureResult.photo;
    if (photo == null) return const CacCapture.failed(CacRejection.cancelled);

    try {
      return _classifyDecodeResult(await _decodePhoto(photo));
    } catch (error) {
      debugPrint('[CacOcr] CAC decode failed: $error');
      return const CacCapture.failed(CacRejection.noCodeFound);
    }
  }

  CacCapture _classifyDecodeResult(Pdf417Read read) {
    final text = read.text;
    if (text != null) return CacCapture.barcode(text);

    final code39 = read.code39Text;
    if (code39 != null) return CacCapture.barcode(code39);

    if (!read.located) return const CacCapture.failed(CacRejection.noCodeFound);

    final modulePx = read.modulePx;
    if (modulePx != null &&
        modulePx < Pdf417ImageDecoder.minDecodableModulePx) {
      return const CacCapture.failed(CacRejection.cardTooSmall);
    }
    return const CacCapture.failed(CacRejection.codeUnreadable);
  }

  Future<Pdf417Read> _decodePhoto(web.File photo) async {
    final bitmap = await web.window
        .createImageBitmap(
          photo,
          web.ImageBitmapOptions(imageOrientation: 'from-image'),
        )
        .toDart;

    try {
      final native = await nativeReader?.read(bitmap);
      if (native != null) return native;

      var located = false;
      double? widestModulePx;

      for (final width in scanWidths) {
        final frame = _rasterizeFrame(bitmap, targetWidth: width);
        if (frame == null) continue;

        final read = decoder.decodeRgba(
          frame.pixels,
          width: frame.width,
          height: frame.height,
        );
        if (read.text != null || read.code39Text != null) return read;

        located |= read.located;
        final modulePx = read.modulePx;
        if (modulePx != null &&
            (widestModulePx == null || modulePx > widestModulePx)) {
          widestModulePx = modulePx;
        }
      }

      return Pdf417Read.miss(located: located, modulePx: widestModulePx);
    } finally {
      bitmap.close();
    }
  }

  _Frame? _rasterizeFrame(web.ImageBitmap bitmap, {required int targetWidth}) {
    final longEdge =
        bitmap.width > bitmap.height ? bitmap.width : bitmap.height;
    if (longEdge == 0) return null;

    final scale = targetWidth >= longEdge ? 1.0 : targetWidth / longEdge;
    final width = (bitmap.width * scale).round();
    final height = (bitmap.height * scale).round();
    if (width <= 0 || height <= 0) return null;

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return null;

    context.drawImage(bitmap, 0, 0, width.toDouble(), height.toDouble());
    final data = context.getImageData(0, 0, width, height);

    final clamped = data.data.toDart;
    return _Frame(
      pixels: Uint8List.view(
        clamped.buffer,
        clamped.offsetInBytes,
        clamped.lengthInBytes,
      ),
      width: width,
      height: height,
    );
  }
}

class _Frame {
  final Uint8List pixels;
  final int width;
  final int height;

  const _Frame({
    required this.pixels,
    required this.width,
    required this.height,
  });
}

CacScannerStrategy createCacScanner({
  Duration captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
  CacSides sides = CacSides.frontAndBack,
  CacScanDiagnostics? diagnostics,
  CacScanTuning tuning = const CacScanTuning(),
}) =>
    WebCacScanner(captureTimeout: captureTimeout);
