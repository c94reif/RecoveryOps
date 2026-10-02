import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:circle_x/core/platform/cac_camera_geometry.dart';
import 'package:circle_x/data/services/cac_ocr_image.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

const rear = CameraDescription(
    name: 'rear',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90);

CameraImage frame({
  int width = 160,
  int height = 120,
  int stride = 168,
  int format = 17,
  Uint8List? bytes,
}) {
  // Construct the same channel shape used by the platform's camera frames.
  // ignore: deprecated_member_use
  return CameraImage.fromPlatformData({
    'width': width,
    'height': height,
    'format': format,
    'planes': [
      {
        'bytes': bytes ?? Uint8List(stride * height * 3 ~/ 2),
        'bytesPerRow': stride,
        'bytesPerPixel': 1,
      }
    ],
  });
}

void main() {
  test('crops the guide out of padded NV21 rows and preserves chroma pairs',
      () {
    const stride = 168;
    const height = 120;
    final bytes = Uint8List(stride * height * 3 ~/ 2)
      ..fillRange(0, stride * height * 3 ~/ 2, 255);
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < 160; col++) {
        bytes[row * stride + col] = (row * 160 + col) % 251;
      }
    }
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < 160; col += 2) {
        bytes[stride * height + row * stride + col] = 80 + row;
        bytes[stride * height + row * stride + col + 1] = 140 + col ~/ 2;
      }
    }
    final original = Uint8List.fromList(bytes);
    final input = cacOcrImage(frame(bytes: bytes), rear,
        DeviceOrientation.landscapeLeft, CacScanSide.back)!;
    // 86% of the visible 160px width, expanded to even NV21 coordinates.
    expect(input.metadata!.size, const Size(140, 88));
    expect(input.metadata!.bytesPerRow, 140);
    expect(input.metadata!.rotation.rawValue, 0);
    expect(input.bytes, hasLength(140 * 88 * 3 ~/ 2));
    expect(input.bytes!.first, bytes[16 * stride + 10]);
    expect(input.bytes![140 * 88 - 1], bytes[103 * stride + 149]);
    expect(input.bytes!.sublist(140 * 88, 140 * 88 + 2), [88, 145]);
    expect(input.bytes, isNot(contains(255)));
    expect(bytes, original);
  });

  test('portrait crops match the covered preview rather than the whole sensor',
      () {
    final input = cacOcrImage(
        frame(), rear, DeviceOrientation.portraitUp, CacScanSide.back)!;
    expect(input.metadata!.size, const Size(68, 104));
    expect(input.metadata!.rotation.rawValue, 90);
    final front = cacOcrImage(
        frame(), rear, DeviceOrientation.landscapeLeft, CacScanSide.front)!;
    expect(front.metadata!.size, const Size(60, 96));
  });

  test('each device orientation gets the correct rear and front rotation', () {
    const frontCamera = CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270);
    const rearAngles = [90, 270, 0, 180];
    const frontAngles = [270, 90, 0, 180];
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
    for (var index = 0; index < orientations.length; index++) {
      expect(CacCameraGeometry.imageRotation(rear, orientations[index]),
          rearAngles[index]);
      expect(CacCameraGeometry.imageRotation(frontCamera, orientations[index]),
          frontAngles[index]);
      for (final side in CacScanSide.values) {
        final image = cacOcrImage(frame(), rear, orientations[index], side)!;
        expect(image.metadata!.rotation.rawValue, rearAngles[index]);
        expect(image.bytes!.length,
            image.metadata!.size.width * image.metadata!.size.height * 1.5);
      }
    }
  });

  test('invalid frame buffers are skipped instead of OCRing the entire frame',
      () {
    for (final image in [
      frame(format: 35),
      frame(width: 161),
      frame(height: 121),
      frame(stride: 100),
      frame(bytes: Uint8List(10)),
      frame(width: 0),
    ]) {
      expect(
          cacOcrImage(
              image, rear, DeviceOrientation.portraitUp, CacScanSide.back),
          isNull);
    }
  });

  test('metering points account for portrait and landscape preview cropping',
      () {
    expect(
        CacCameraGeometry.meteringPoint(
            const Offset(0, 0), const Size(480, 640)),
        const Offset(0, 0.21875));
    expect(
        CacCameraGeometry.meteringPoint(
            const Offset(1, 1), const Size(1920, 1080)),
        const Offset(0.875, 1));
    expect(
        CacCameraGeometry.meteringPoint(
            const Offset(-1, 2), const Size(1920, 1080)),
        const Offset(0.125, 1));
  });
}
