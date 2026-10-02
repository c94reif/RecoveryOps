import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> focusCacCamera(CameraController camera, Offset point) async {
  final operations = <Future<void> Function()>[
    () => camera.setFocusMode(FocusMode.auto),
    () => camera.setExposureMode(ExposureMode.auto),
    if (camera.value.focusPointSupported) () => camera.setFocusPoint(point),
    if (camera.value.exposurePointSupported)
      () => camera.setExposurePoint(point),
  ];
  for (final operation in operations) {
    try {
      await operation();
    } on CameraException catch (error) {
      debugPrint('[CircleX] camera metering unavailable: ${error.code}');
    } on MissingPluginException {
      // Some host camera implementations do not expose metering controls.
    }
  }
}
