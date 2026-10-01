import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

abstract interface class OcrCameraPreview {
  ValueListenable<CameraController?> get preview;
}
