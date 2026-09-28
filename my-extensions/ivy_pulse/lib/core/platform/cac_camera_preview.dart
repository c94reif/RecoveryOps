import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

abstract interface class CacCameraPreview {
  ValueListenable<CameraController?> get preview;
  ValueListenable<String> get guidance;
}
