import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

abstract interface class CacCameraPreview {
  ValueListenable<CameraController?> get preview;
  ValueListenable<String> get guidance;
  ValueListenable<CacScanSide> get side;
}
