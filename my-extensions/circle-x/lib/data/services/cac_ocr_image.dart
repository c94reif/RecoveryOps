import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:circle_x/core/platform/cac_camera_geometry.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

/// Crops the actual NV21 pixels to the same card guide shown in the preview.
/// The complete card preserves labels and the front-side name guard.
InputImage? cacOcrImage(CameraImage frame, CameraDescription camera,
    DeviceOrientation orientation, CacScanSide side) {
  if (frame.planes.length != 1 ||
      frame.format.raw != InputImageFormat.nv21.rawValue ||
      frame.width < 2 ||
      frame.height < 2 ||
      frame.width.isOdd ||
      frame.height.isOdd) {
    return null;
  }
  final plane = frame.planes.single;
  final stride = plane.bytesPerRow;
  if (stride < frame.width ||
      plane.bytes.length < stride * frame.height * 3 ~/ 2) {
    return null;
  }
  final angle = CacCameraGeometry.imageRotation(camera, orientation);
  final rotation = InputImageRotationValue.fromRawValue(angle);
  if (rotation == null) return null;
  final sideways = angle == 90 || angle == 270;
  final upright = sideways
      ? Size(frame.height.toDouble(), frame.width.toDouble())
      : Size(frame.width.toDouble(), frame.height.toDouble());
  final card = CacCameraGeometry.cardInImage(upright, side);
  // The guide is centered, so undoing rotation only swaps its dimensions.
  final rawCrop = Rect.fromCenter(
    center: Offset(frame.width / 2, frame.height / 2),
    width: sideways ? card.height : card.width,
    height: sideways ? card.width : card.height,
  );
  // NV21 shares each VU pair across a 2x2 pixel block.
  final left = (rawCrop.left / 2).floor() * 2;
  final top = (rawCrop.top / 2).floor() * 2;
  final right = (rawCrop.right / 2).ceil() * 2;
  final bottom = (rawCrop.bottom / 2).ceil() * 2;
  final width = right - left;
  final height = bottom - top;
  final cropped = Uint8List(width * height * 3 ~/ 2);
  for (var row = 0; row < height; row++) {
    final source = (top + row) * stride + left;
    cropped.setRange(row * width, (row + 1) * width, plane.bytes, source);
  }
  final chromaStart = stride * frame.height;
  for (var row = 0; row < height ~/ 2; row++) {
    final source = chromaStart + (top ~/ 2 + row) * stride + left;
    final target = width * height + row * width;
    cropped.setRange(target, target + width, plane.bytes, source);
  }
  return InputImage.fromBytes(
    bytes: cropped,
    metadata: InputImageMetadata(
      size: Size(width.toDouble(), height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: width,
    ),
  );
}
