import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

/// Shared by the visible guide, OCR crop and camera metering points.
abstract final class CacCameraGeometry {
  static const previewAspect = 4 / 3;
  static const cardAspect = 85.6 / 53.98;

  static Rect guide(Size viewport, CacScanSide side) {
    final front = side == CacScanSide.front;
    final width =
        front ? viewport.height * 0.78 / cardAspect : viewport.width * 0.86;
    return Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: width,
      height: front ? width * cardAspect : width / cardAspect,
    );
  }

  /// The portion of the full upright image visible through BoxFit.cover.
  static Rect visibleImage(Size image) {
    final width = image.aspectRatio > previewAspect
        ? image.height * previewAspect
        : image.width;
    return Rect.fromCenter(
      center: image.center(Offset.zero),
      width: width,
      height: width / previewAspect,
    );
  }

  static Rect cardInImage(Size uprightImage, CacScanSide side) {
    final visible = visibleImage(uprightImage);
    return guide(visible.size, side).shift(visible.topLeft);
  }

  static Offset meteringPoint(Offset tap, Size uprightPreview) {
    final visible = visibleImage(uprightPreview);
    return Offset(
      (visible.left + tap.dx.clamp(0.0, 1.0) * visible.width) /
          uprightPreview.width,
      (visible.top + tap.dy.clamp(0.0, 1.0) * visible.height) /
          uprightPreview.height,
    );
  }

  static Offset textTarget(CacScanSide side) {
    const viewport = Size(4, 3);
    final card = guide(viewport, side);
    // Name below the front photo; printed ID above the back barcode strip.
    final y = side == CacScanSide.front ? 0.65 : 0.35;
    return Offset(0.5, (card.top + card.height * y) / viewport.height);
  }

  static bool isLandscape(DeviceOrientation orientation) =>
      orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;

  static Size uprightPreview(CameraController camera) {
    final size = camera.value.previewSize!;
    return isLandscape(camera.value.deviceOrientation)
        ? size
        : Size(size.height, size.width);
  }

  static int imageRotation(
      CameraDescription camera, DeviceOrientation orientation) {
    final deviceRotation = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
  }
}
