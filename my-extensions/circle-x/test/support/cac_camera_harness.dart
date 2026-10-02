import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/services/android_cac_scanner.dart';

class CacCameraHarness {
  static const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  static const imageChannel =
      MethodChannel('plugins.flutter.io/camera/imageStream');
  static const ocrChannel = MethodChannel('google_mlkit_text_recognizer');
  static const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cameraCalls = <MethodCall>[];
  final ocrCalls = <MethodCall>[];
  final resolutions = <ResolutionPreset>[];
  final cameras = <CameraController>[];
  late final AndroidCacScanner scanner = AndroidCacScanner(
    cameraFactory: (description, resolution) {
      resolutions.add(resolution);
      final camera = _Camera(description, resolution);
      cameras.add(camera);
      return camera;
    },
  );
  var lines = <String>[];
  var rejectHigherResolution = false;
  var rejectFocus = false;
  var supportsMetering = true;
  Completer<void>? pendingInitialize;
  Completer<Map<String, Object>>? pendingOcr;
  int _cameraId = 0;

  void install() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(cameraChannel, (call) async {
      cameraCalls.add(call);
      switch (call.method) {
        case 'availableCameras':
          return [
            {'name': 'rear', 'lensFacing': 'back', 'sensorOrientation': 90}
          ];
        case 'create':
          if (rejectHigherResolution &&
              resolutions.last == ResolutionPreset.veryHigh) {
            throw PlatformException(code: 'unsupportedResolution');
          }
          return {'cameraId': ++_cameraId};
        case 'initialize':
          await pendingInitialize?.future;
          await messenger.handlePlatformMessage(
              'flutter.io/cameraPlugin/camera$_cameraId',
              codec.encodeMethodCall(MethodCall('initialized', {
                'previewWidth': 640.0,
                'previewHeight': 480.0,
                'exposureMode': 'auto',
                'exposurePointSupported': supportsMetering,
                'focusMode': 'auto',
                'focusPointSupported': supportsMetering,
              })),
              null);
          return null;
        case 'setFocusMode':
        case 'setFocusPoint':
          if (rejectFocus) throw PlatformException(code: 'unsupportedFocus');
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(imageChannel, (_) async => null);
    messenger.setMockMethodCallHandler(ocrChannel, (call) async {
      ocrCalls.add(call);
      if (call.method == 'vision#startTextRecognizer') {
        return pendingOcr?.future ?? recognized(lines);
      }
      return null;
    });
  }

  static Map<String, Object> recognized(List<String> lines) {
    const box = {'left': 10.0, 'top': 10.0, 'right': 100.0, 'bottom': 30.0};
    return {
      'text': lines.join('\n'),
      'blocks': [
        {
          'text': lines.join('\n'),
          'rect': box,
          'recognizedLanguages': <String>[],
          'points': <Object>[],
          'lines': [
            for (final line in lines)
              {
                'text': line,
                'rect': box,
                'recognizedLanguages': <String>[],
                'points': <Object>[],
                'elements': <Object>[],
              },
          ],
        },
      ],
    };
  }

  Future<void> flush() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> frame(List<String> text) async {
    lines = text;
    await messenger.handlePlatformMessage(
        imageChannel.name,
        codec.encodeSuccessEnvelope({
          'width': 640,
          'height': 480,
          'format': 17,
          'planes': [
            {
              'bytes': Uint8List(640 * 480 * 3 ~/ 2),
              'bytesPerRow': 640,
              'bytesPerPixel': 1,
            }
          ],
        }),
        null);
    await flush();
  }

  Future<void> rotate(String orientation) async {
    await messenger.handlePlatformMessage(
        'flutter.io/cameraPlugin/device',
        codec.encodeMethodCall(
            MethodCall('orientation_changed', {'orientation': orientation})),
        null);
    await flush();
  }

  Future<void> dispose() async {
    if (pendingInitialize case final pending? when !pending.isCompleted) {
      pending.complete();
    }
    if (pendingOcr case final pending? when !pending.isCompleted) {
      pending.complete(recognized([]));
    }
    await scanner.cancel();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(cameraChannel, null);
    messenger.setMockMethodCallHandler(imageChannel, null);
    messenger.setMockMethodCallHandler(ocrChannel, null);
  }
}

class _Camera extends CameraController {
  _Camera(super.description, super.resolutionPreset)
      : super(enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

  @override
  bool supportsImageStreaming() => true;
}
