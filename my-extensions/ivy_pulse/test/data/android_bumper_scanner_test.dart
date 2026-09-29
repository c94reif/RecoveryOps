import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/services/android_bumper_scanner.dart';
import 'package:ivy_pulse/domain/services/bumper_scanner_strategy.dart';

// Exercise the real adapter using synthetic platform frames on the test host.
class _Scanner extends AndroidBumperScanner {
  _Scanner() : super(cameraFactory: _Camera.new);

  @override
  bool get isSupported => true;
}

class _Camera extends CameraController {
  _Camera(CameraDescription description)
      : super(description, ResolutionPreset.high,
            enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

  // The host's method-channel test backend streams synthetic frames.
  @override
  bool supportsImageStreaming() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  const imageChannel = MethodChannel('plugins.flutter.io/camera/imageStream');
  const ocrChannel = MethodChannel('google_mlkit_text_recognizer');
  const codec = StandardMethodCodec();
  late _Scanner scanner;
  late List<String> cameraCalls;
  late List<MethodCall> ocrCalls;
  Completer<Map<String, Object>>? pendingOcr;

  Map<String, Object> recognized() {
    const box = {'left': 0.0, 'top': 0.0, 'right': 10.0, 'bottom': 10.0};
    return {
      'text': '4ID 1-8IN\nA-11',
      'blocks': [
        {
          'text': '4ID 1-8IN\nA-11',
          'rect': box,
          'recognizedLanguages': <String>[],
          'points': <Object>[],
          'lines': [
            for (final line in ['4ID 1-8IN', 'A-11'])
              {
                'text': line,
                'rect': box,
                'recognizedLanguages': <String>[],
                'points': <Object>[],
                'elements': <Object>[]
              },
          ],
        },
      ],
    };
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    scanner = _Scanner();
    cameraCalls = [];
    ocrCalls = [];
    pendingOcr = null;
    messenger.setMockMethodCallHandler(cameraChannel, (call) async {
      cameraCalls.add(call.method);
      switch (call.method) {
        case 'availableCameras':
          return [
            {'name': 'rear', 'lensFacing': 'back', 'sensorOrientation': 90}
          ];
        case 'create':
          return {'cameraId': 1};
        case 'initialize':
          await messenger.handlePlatformMessage(
              'flutter.io/cameraPlugin/camera1',
              codec.encodeMethodCall(const MethodCall('initialized', {
                'previewWidth': 640.0,
                'previewHeight': 480.0,
                'exposureMode': 'auto',
                'exposurePointSupported': true,
                'focusMode': 'auto',
                'focusPointSupported': true,
              })),
              null);
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(imageChannel, (_) async => null);
    messenger.setMockMethodCallHandler(ocrChannel, (call) async {
      ocrCalls.add(call);
      if (call.method == 'vision#startTextRecognizer') {
        return pendingOcr?.future ?? recognized();
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(cameraChannel, null);
    messenger.setMockMethodCallHandler(imageChannel, null);
    messenger.setMockMethodCallHandler(ocrChannel, null);
  });

  void scannerTest(String name, Future<void> Function() run) {
    test(name, () async {
      try {
        await run();
      } finally {
        if (pendingOcr != null && !pendingOcr!.isCompleted) {
          pendingOcr!.complete(recognized());
        }
        await scanner.dispose();
      }
    });
  }

  Future<void> frame() async {
    await messenger.handlePlatformMessage(
        imageChannel.name,
        codec.encodeSuccessEnvelope({
          'width': 4,
          'height': 4,
          'format': 17,
          'planes': [
            {
              'bytes': Uint8List(24),
              'bytesPerRow': 4,
              'bytesPerPixel': 1,
              'width': 4,
              'height': 4
            }
          ],
        }),
        null);
    await Future<void>.delayed(Duration.zero);
  }

  scannerTest('opening and streaming do not read until requested', () async {
    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    await frame();
    expect(ocrCalls, isEmpty);
    final read = scanner.read();
    await frame();
    expect(await read, ['4ID 1-8IN', 'A-11']);
    expect(
        ocrCalls.where((call) => call.method == 'vision#startTextRecognizer'),
        hasLength(1));
    await frame();
    expect(ocrCalls, hasLength(1));
    expect(cameraCalls, isNot(contains('takePicture')));
    await scanner.stop();
    expect(scanner.preview.value, isNull);
    expect(cameraCalls, containsAll(['stopImageStream', 'dispose']));
    expect(ocrCalls.last.method, 'vision#closeTextRecognizer');
  });

  scannerTest('a request with no camera frames times out and can be retried',
      () async {
    await scanner.start();
    final outcome =
        expectLater(scanner.read(), throwsA(BumperScanFailure.timedOut));
    await Future<void>.delayed(const Duration(seconds: 16));
    await outcome;
    final retry = scanner.read();
    await frame();
    expect(await retry, ['4ID 1-8IN', 'A-11']);
  });

  scannerTest('cancelled OCR is dropped and the next camera session can read',
      () async {
    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    pendingOcr = Completer<Map<String, Object>>();
    final outcome =
        expectLater(scanner.read(), throwsA(BumperScanFailure.cancelled));
    await frame();
    final stopped = scanner.stop();
    await Future<void>.delayed(Duration.zero);
    await outcome;
    expect(scanner.preview.value, isNull);
    pendingOcr!.complete(recognized());
    await Future<void>.delayed(Duration.zero);
    await stopped;
    pendingOcr = null;
    await scanner.start();
    await Future<void>.delayed(Duration.zero);
    final retry = scanner.read();
    await frame();
    expect(await retry, ['4ID 1-8IN', 'A-11']);
  });

  scannerTest('rotating the device rotates the image metadata sent to OCR',
      () async {
    await scanner.start();
    await messenger.handlePlatformMessage(
        'flutter.io/cameraPlugin/device',
        codec.encodeMethodCall(const MethodCall(
            'orientation_changed', {'orientation': 'landscapeLeft'})),
        null);
    await Future<void>.delayed(Duration.zero);
    final read = scanner.read();
    await frame();
    await read;
    final data = ocrCalls.single.arguments['imageData'] as Map;
    expect(data['metadata']['rotation'], 0);
  });
}
