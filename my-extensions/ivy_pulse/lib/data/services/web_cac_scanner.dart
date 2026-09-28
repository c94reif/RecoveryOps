import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/services/native_barcode_reader.dart';
import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

class WebCacScanner implements CacScannerStrategy {
  final Pdf417ImageDecoder decoder;

  final NativeBarcodeReader? nativeReader;

  WebCacScanner({
    this.decoder = const Pdf417ImageDecoder(),
    NativeBarcodeReader? nativeReader,
    bool useNativeReader = true,
  }) : nativeReader = nativeReader ??
            (useNativeReader && NativeBarcodeReader.isSupported
                ? NativeBarcodeReader()
                : null);

  static const List<int> scanWidths = [1600, 2600, 1000];

  static const Duration cancelGrace = Duration(seconds: 12);

  void Function(web.File?)? _completePendingCapture;

  int _captureGeneration = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> cancel() async {
    _completePendingCapture?.call(null);
  }

  @override
  Future<CacCapture> capture() async {
    final ({web.File? photo, bool timedOut}) captureResult;
    try {
      captureResult = await _capturePhoto();
    } catch (error) {
      debugPrint('[IvyPulse] CAC capture failed: $error');
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
      debugPrint('[IvyPulse] CAC decode failed: $error');
      return const CacCapture.failed(CacRejection.noCodeFound);
    }
  }

  Future<({web.File? photo, bool timedOut})> _capturePhoto() {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = 'image/*'
      ..capture = 'environment';
    input.style.display = 'none';
    web.document.body?.appendChild(input);

    final completer = Completer<({web.File? photo, bool timedOut})>();
    final generation = ++_captureGeneration;
    Timer? cancelTimer;
    Timer? timeoutTimer;
    JSFunction? onFocus;
    var timedOut = false;
    DateTime? focusReturnedAt;

    void completePhotoCapture(web.File? file) {
      if (_captureGeneration == generation) _completePendingCapture = null;
      cancelTimer?.cancel();
      timeoutTimer?.cancel();
      if (onFocus != null) {
        web.window.removeEventListener('focus', onFocus);
        onFocus = null;
      }
      if (!completer.isCompleted) {
        completer.complete((photo: file, timedOut: timedOut));
      }
      input.remove();
    }

    _completePendingCapture = completePhotoCapture;

    input.onchange = (web.Event _) {
      final files = input.files;
      final photo = files != null && files.length > 0 ? files.item(0) : null;
      final since = focusReturnedAt;
      if (since != null) {
        final photoArrivalDelayMs =
            DateTime.now().difference(since).inMilliseconds;
        debugPrint(
            '[IvyPulse] CAC photo arrived ${photoArrivalDelayMs}ms after focus '
            '(grace ${cancelGrace.inMilliseconds}ms)');
      }
      completePhotoCapture(photo);
    }.toJS;

    input.oncancel = ((web.Event _) => completePhotoCapture(null)).toJS;

    onFocus = ((web.Event _) {
      cancelTimer?.cancel();
      focusReturnedAt = DateTime.now();
      cancelTimer = Timer(cancelGrace, () {
        debugPrint('[IvyPulse] CAC photo did not arrive within '
            '${cancelGrace.inMilliseconds}ms of focus — treating as cancelled');
        completePhotoCapture(null);
      });
    }).toJS;
    web.window.addEventListener('focus', onFocus);

    timeoutTimer = Timer(AppConstants.cacCaptureTimeout, () {
      timedOut = true;
      completePhotoCapture(null);
    });

    input.click();
    return completer.future;
  }

  CacCapture _classifyDecodeResult(Pdf417Read read) {
    final text = read.text;
    if (text != null) return CacCapture.read(text);

    final code39 = read.code39Text;
    if (code39 != null) return CacCapture.read(code39);

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

CacScannerStrategy createCacScanner() => WebCacScanner();
