import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/pdf417.dart';
import 'package:zxing_lib/zxing.dart';

class Pdf417Read {
  final String? text;

  final bool located;

  final double? modulePx;

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

class Pdf417ImageDecoder {
  const Pdf417ImageDecoder();

  @visibleForTesting
  static int locateSweeps = 0;

  static const double minDecodableModulePx = 1.5;

  static const double _cropPaddingFraction = 0.04;

  static const int _minCropSizePx = 16;

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
          RGBLuminanceSource.orig(width, height, _rgbaToLuminance(rgba)),
        ),
      );
    } catch (error) {
      debugPrint('[IvyPulse] PDF417 binarise failed: $error');
      return const Pdf417Read.miss();
    }

    final fullFrameRead = _readPdf417(bitmap);
    final fullFrameText = fullFrameRead.text;
    if (fullFrameText != null) return Pdf417Read.hit(fullFrameText);

    var located = fullFrameRead.located;

    final symbol = _locateSymbol(bitmap);
    if (symbol != null) {
      located = true;
      final cropBounds = symbol.crop;
      if (cropBounds != null && bitmap.isCropSupported) {
        try {
          final croppedRead = _readPdf417(
            bitmap.crop(cropBounds.left, cropBounds.top, cropBounds.width,
                cropBounds.height),
          );
          final croppedText = croppedRead.text;
          if (croppedText != null) return Pdf417Read.hit(croppedText);
        } catch (error) {
          debugPrint('[IvyPulse] PDF417 crop retry failed: $error');
        }
      }
    }

    debugPrint(
      '[IvyPulse] PDF417 miss: located=$located '
      'modulePx=${symbol?.modulePx?.toStringAsFixed(2)} frame=${width}x$height',
    );

    final code39 = located ? null : _readCode39(bitmap);

    return Pdf417Read.miss(
      located: located,
      modulePx: symbol?.modulePx,
      code39Text: code39,
    );
  }

  ({String? text, bool located}) _readPdf417(BinaryBitmap bitmap) {
    try {
      return (text: PDF417Reader().decode(bitmap).text, located: true);
    } on ChecksumException catch (_) {
      return (text: null, located: true);
    } on FormatsException catch (_) {
      return (text: null, located: true);
    } on NotFoundException catch (_) {
      return (text: null, located: false);
    } catch (error) {
      debugPrint('[IvyPulse] PDF417 decode miss: $error');
      return (text: null, located: false);
    }
  }

  _LocatedSymbol? _locateSymbol(BinaryBitmap bitmap) {
    locateSweeps++;

    final PDF417DetectorResult detection;
    try {
      detection = Detector.detect(bitmap, null, false);
    } catch (error) {
      debugPrint('[IvyPulse] PDF417 locate failed: $error');
      return null;
    }
    if (detection.points.isEmpty) return null;

    final vertices = detection.points.first;

    final start = vertices.isNotEmpty ? vertices[0] : null;
    final startEnd = vertices.length > 4 ? vertices[4] : null;

    double? modulePx;
    if (start != null && startEnd != null) {
      final span = (startEnd.x - start.x).abs();
      if (span > 0) modulePx = span / PDF417Common.modulesInCodeword;
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var vertexCount = 0;
    for (final vertex in vertices) {
      if (vertex == null) continue;
      final (x, y) = _mapPointToOriginalFrame(
        vertex,
        detection.rotation,
        bitmap.width,
        bitmap.height,
      );
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      vertexCount++;
    }
    if (vertexCount < 2) return _LocatedSymbol(modulePx: modulePx);

    final cropPadding = math.max(
      math.max(maxX - minX, maxY - minY) * _cropPaddingFraction,
      4.0,
    );

    final left = math.max(0, (minX - cropPadding).floor());
    final top = math.max(0, (minY - cropPadding).floor());
    final right = math.min(bitmap.width, (maxX + cropPadding).ceil());
    final bottom = math.min(bitmap.height, (maxY + cropPadding).ceil());
    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth < _minCropSizePx || cropHeight < _minCropSizePx) {
      return _LocatedSymbol(modulePx: modulePx);
    }
    if (cropWidth >= bitmap.width * 0.95 &&
        cropHeight >= bitmap.height * 0.95) {
      return _LocatedSymbol(modulePx: modulePx);
    }

    return _LocatedSymbol(
      modulePx: modulePx,
      crop: _CropBox(left, top, cropWidth, cropHeight),
    );
  }

  String? _readCode39(BinaryBitmap bitmap) {
    try {
      return Code39Reader()
          .decode(bitmap, const DecodeHint(tryHarder: true))
          .text;
    } on NotFoundException catch (_) {
      return null;
    } on FormatsException catch (_) {
      return null;
    } on ChecksumException catch (_) {
      return null;
    } catch (error) {
      debugPrint('[IvyPulse] Code 39 sweep failed: $error');
      return null;
    }
  }

  static (double, double) _mapPointToOriginalFrame(
    ResultPoint point,
    int rotation,
    int width,
    int height,
  ) {
    switch (rotation % 360) {
      case 90:
        return (width - 1 - point.y, point.x);
      case 180:
        return (width - 1 - point.x, height - 1 - point.y);
      case 270:
        return (point.y, height - 1 - point.x);
      default:
        return (point.x, point.y);
    }
  }

  static Uint8List _rgbaToLuminance(Uint8List rgba) {
    final pixelCount = rgba.length ~/ 4;
    final luminance = Uint8List(pixelCount);
    for (var pixelIndex = 0; pixelIndex < pixelCount; pixelIndex++) {
      final rgbaOffset = pixelIndex * 4;
      luminance[pixelIndex] = (rgba[rgbaOffset] +
              (rgba[rgbaOffset + 1] << 1) +
              rgba[rgbaOffset + 2]) >>
          2;
    }
    return luminance;
  }
}

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
