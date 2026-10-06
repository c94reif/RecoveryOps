import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/infrastructure/android/android_cac_scanner.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';

class CacCameraHarness {
  final Duration captureTimeout;
  final CacSides sides;
  final CacScanDiagnostics? diagnostics;

  CacCameraHarness({
    this.captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
    this.sides = CacSides.frontAndBack,
    this.diagnostics,
  });

  static const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  static const imageChannel =
      MethodChannel('plugins.flutter.io/camera/imageStream');
  static const ocrChannel = MethodChannel('google_mlkit_text_recognizer');
  static const barcodeChannel = MethodChannel('google_mlkit_barcode_scanning');
  static const codec = StandardMethodCodec();
  static const cardFront = ['NAME', 'SMITH, JOHN A', 'RANK', 'SGT'];
  static const cardBack = ['DoD ID Number 1087987498'];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cameraCalls = <MethodCall>[];
  final ocrCalls = <MethodCall>[];
  final barcodeCalls = <MethodCall>[];
  final resolutions = <ResolutionPreset>[];
  final cameras = <CameraController>[];
  late final AndroidCacScanner scanner = AndroidCacScanner(
    captureTimeout: captureTimeout,
    sides: sides,
    diagnostics: diagnostics,
    cameraFactory: (description, resolution) {
      resolutions.add(resolution);
      final camera = _Camera(description, resolution);
      cameras.add(camera);
      return camera;
    },
  );
  var lines = <String>[];
  var codes = <Map<String, Object?>>[];
  var failBarcodes = false;
  double? lineConfidence;
  var rejectHigherResolution = false;
  var rejectFocus = false;
  var supportsMetering = true;
  var torchless = false;
  var failCreate = false;
  var failInitialize = false;
  var minExposureOffset = -2.0;

  /// Characters ML Kit doubts, by their place in the line.
  var doubted = <String, Set<int>>{};
  Completer<void>? pendingInitialize;
  Completer<Map<String, Object>>? pendingOcr;

  /// Unique across tests: the camera plugin's listeners outlive a harness.
  static int _cameraId = 0;

  /// Like a phone, one camera at a time: another is refused until it closes.
  final _openCameras = <int>{};

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
          if (failCreate || _openCameras.isNotEmpty) {
            throw PlatformException(code: 'cameraInUse');
          }
          if (rejectHigherResolution &&
              resolutions.last == AndroidCacScanner.sharperResolution) {
            throw PlatformException(code: 'unsupportedResolution');
          }
          _openCameras.add(++_cameraId);
          return {'cameraId': _cameraId};
        case 'dispose':
          _openCameras.remove((call.arguments as Map)['cameraId']);
          return null;
        case 'initialize':
          await pendingInitialize?.future;
          if (failInitialize) {
            throw PlatformException(code: 'cameraDisconnected');
          }
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
        case 'setFlashMode':
          if (torchless) throw PlatformException(code: 'setFlashModeFailed');
          return null;
        case 'getMinExposureOffset':
          return minExposureOffset;
        case 'getMaxExposureOffset':
          return 2.0;
        case 'getExposureOffsetStepSize':
          return 0.5;
        case 'setExposureOffset':
          return (call.arguments as Map)['offset'];
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(imageChannel, (_) async => null);
    messenger.setMockMethodCallHandler(ocrChannel, (call) async {
      ocrCalls.add(call);
      if (call.method == 'vision#startTextRecognizer') {
        return pendingOcr?.future ??
            recognized(lines, confidence: lineConfidence, doubted: doubted);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(barcodeChannel, (call) async {
      barcodeCalls.add(call);
      if (call.method != 'vision#startBarcodeScanner') return null;
      if (failBarcodes) throw PlatformException(code: 'barcodeUnavailable');
      return codes;
    });
  }

  static Map<String, Object?> pdf417(String value) => _barcode(0x0800, value);

  static Map<String, Object?> code39(String value) => _barcode(0x0002, value);

  static Map<String, Object?> _barcode(int format, String value) => {
        'type': 7,
        'format': format,
        'displayValue': value,
        'rawValue': value,
        'rawBytes': null,
        'rect': {'left': 0.0, 'top': 0.0, 'right': 10.0, 'bottom': 10.0},
        'points': <Object>[],
      };

  static Map<String, Object> recognized(List<String> lines,
      {double? confidence, Map<String, Set<int>> doubted = const {}}) {
    const box = {'left': 10.0, 'top': 10.0, 'right': 100.0, 'bottom': 30.0};
    Map<String, Object> symbol(String text, bool doubtful) => {
          'text': text,
          'rect': box,
          'recognizedLanguages': <String>[],
          'points': <Object>[],
          'confidence': doubtful ? 0.2 : 0.95,
        };
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
                'elements': [
                  for (final word in RegExp(r'\S+').allMatches(line))
                    {
                      'text': word[0]!,
                      'rect': box,
                      'recognizedLanguages': <String>[],
                      'points': <Object>[],
                      'symbols': [
                        for (var at = word.start; at < word.end; at++)
                          symbol(
                              line[at], doubted[line]?.contains(at) ?? false),
                      ],
                    },
                ],
                if (confidence != null) 'confidence': confidence,
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

  /// Sends one camera frame; [luma] fills its brightness plane.
  Future<void> frame(List<String> text, {Uint8List? luma}) async {
    lines = text;
    final bytes = Uint8List(640 * 480 * 3 ~/ 2);
    if (luma != null) bytes.setRange(0, luma.length, luma);
    await messenger.handlePlatformMessage(
        imageChannel.name,
        codec.encodeSuccessEnvelope({
          'width': 640,
          'height': 480,
          'format': 17,
          'planes': [
            {
              'bytes': bytes,
              'bytesPerRow': 640,
              'bytesPerPixel': 1,
            }
          ],
        }),
        null);
    await flush();
  }

  Future<void> frames(List<String> text, int count, {Uint8List? luma}) async {
    for (var i = 0; i < count; i++) {
      await frame(text, luma: luma);
    }
  }

  /// Reads the front through to the flip.
  Future<void> readFront([List<String> lines = cardFront]) async {
    await frames(lines, CacOcrSession.framesToAgree);
    expect(scanner.side.value, CacScanSide.back);
  }

  int get ocrRuns => ocrCalls
      .where((call) => call.method == 'vision#startTextRecognizer')
      .length;

  /// A 640x480 brightness plane of 4-pixel squares in two shades.
  static Uint8List checkerboard({int light = 200}) => Uint8List.fromList([
        for (var y = 0; y < 480; y++)
          for (var x = 0; x < 640; x++) (x ~/ 4 + y ~/ 4).isEven ? light : 0,
      ]);

  /// Moves the app through Flutter's lifecycle as Android would.
  Future<void> lifecycle(AppLifecycleState state) async {
    await messenger.handlePlatformMessage(SystemChannels.lifecycle.name,
        SystemChannels.lifecycle.codec.encodeMessage(state.toString()), null);
    await flush();
  }

  /// The modes the scanner set through [method], in order.
  List<Object?> modes(String method) => [
        for (final call in cameraCalls)
          if (call.method == method) (call.arguments as Map)['mode'],
      ];

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
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      await lifecycle(AppLifecycleState.resumed);
    }
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(cameraChannel, null);
    messenger.setMockMethodCallHandler(imageChannel, null);
    messenger.setMockMethodCallHandler(ocrChannel, null);
    messenger.setMockMethodCallHandler(barcodeChannel, null);
  }
}

class _Camera extends CameraController {
  _Camera(super.description, super.resolutionPreset)
      : super(enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

  @override
  bool supportsImageStreaming() => true;
}
