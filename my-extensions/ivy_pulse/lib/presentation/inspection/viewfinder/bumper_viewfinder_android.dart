import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivy_pulse/core/platform/ocr_camera_preview.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/services/bumper_scanner_strategy.dart';

Widget? buildBumperViewfinder(BumperScannerStrategy scanner) {
  if (scanner is! OcrCameraPreview) return null;
  final source = scanner as OcrCameraPreview;
  return ValueListenableBuilder<CameraController?>(
    valueListenable: source.preview,
    builder: (context, camera, _) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: camera == null || !camera.value.isInitialized
              ? const Center(
                  child:
                      Icon(Icons.photo_camera_outlined, color: textSecondary))
              : _fullWidthPreview(camera),
        ),
      ),
    ),
  );
}

Widget _fullWidthPreview(CameraController camera) {
  return ValueListenableBuilder<CameraValue>(
    valueListenable: camera,
    builder: (context, value, _) {
      final orientation = value.previewPauseOrientation ??
          value.lockedCaptureOrientation ??
          value.deviceOrientation;
      final landscape = orientation == DeviceOrientation.landscapeLeft ||
          orientation == DeviceOrientation.landscapeRight;
      final size = value.previewSize!;
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: landscape ? size.width : size.height,
          height: landscape ? size.height : size.width,
          child: CameraPreview(camera),
        ),
      );
    },
  );
}
