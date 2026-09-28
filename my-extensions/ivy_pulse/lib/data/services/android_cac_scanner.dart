import 'package:ivy_pulse/core/platform/cac_camera_preview.dart';
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/find_dod_id.dart';

class AndroidCacScanner implements CacScannerStrategy, CacCameraPreview {
  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);

  @override
  final ValueNotifier<String> guidance = ValueNotifier('');

  static const int framesToAgree = 2;

  Completer<CacCapture>? _inFlight;
  CameraController? _controller;
  TextRecognizer? _recognizer;
  Timer? _timeout;
  bool _frameBusy = false;
  String? _candidate;
  int _agreed = 0;

  @override
  Future<bool> isAvailable() async => Platform.isAndroid;

  @override
  Future<CacCapture> capture() async {
    final open = _inFlight;
    if (open != null) return open.future;

    final completer = Completer<CacCapture>();
    _inFlight = completer;
    _candidate = null;
    _agreed = 0;
    guidance.value = 'Starting camera…';

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
        return await completer.future;
      }
      final rear = cameras.firstWhere(
        (candidateCamera) =>
            candidateCamera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (_inFlight != completer) {
        await controller.dispose();
        return await completer.future;
      }
      _controller = controller;
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      preview.value = controller;
      guidance.value = 'Fill the box with the BACK of the card';

      _timeout = Timer(AppConstants.cacCaptureTimeout, () {
        _completeCapture(const CacCapture.failed(CacRejection.noCodeFound));
      });
      await controller.startImageStream(_onFrame);
    } on CameraException catch (error) {
      debugPrint(
          '[IvyPulse] camera unavailable: ${error.code} ${error.description}');
      _completeCapture(const CacCapture.failed(CacRejection.noCamera));
    } catch (error) {
      debugPrint('[IvyPulse] CAC scanner failed to start: $error');
      _completeCapture(const CacCapture.failed(CacRejection.noCamera));
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _completeCapture(const CacCapture.failed(CacRejection.cancelled));
  }

  Future<void> _onFrame(CameraImage image) async {
    final recognizer = _recognizer;
    final controller = _controller;
    if (_frameBusy || recognizer == null || controller == null) return;
    _frameBusy = true;
    try {
      final input = _toInputImage(image, controller.description);
      if (input == null) return;
      final result = await recognizer.processImage(input);
      if (_inFlight == null) return;

      final lines = <String>[
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ];
      final found = findDodId(lines);
      if (found == null) {
        _candidate = null;
        _agreed = 0;
        guidance.value = lines.isEmpty
            ? 'Fill the box with the BACK of the card'
            : 'Reading… hold the DoD ID number steady';
        return;
      }
      if (found == _candidate) {
        _agreed++;
      } else {
        _candidate = found;
        _agreed = 1;
      }
      if (_agreed >= framesToAgree) {
        guidance.value = 'Read';
        unawaited(HapticFeedback.mediumImpact());
        _completeCapture(CacCapture.read(found));
      } else {
        guidance.value = 'Almost — hold still';
      }
    } catch (error) {
      debugPrint('[IvyPulse] OCR frame skipped: $error');
    } finally {
      _frameBusy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (format != InputImageFormat.nv21) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.single;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _completeCapture(CacCapture outcome) {
    final completer = _inFlight;
    if (completer == null) return;
    _inFlight = null;
    _timeout?.cancel();
    _timeout = null;

    final controller = _controller;
    final recognizer = _recognizer;
    _controller = null;
    _recognizer = null;
    preview.value = null;

    unawaited(() async {
      try {
        if (controller != null) {
          if (controller.value.isStreamingImages) {
            await controller.stopImageStream();
          }
          await controller.dispose();
        }
      } catch (error) {
        debugPrint('[IvyPulse] camera teardown: $error');
      }
      await recognizer?.close();
    }());

    if (!completer.isCompleted) completer.complete(outcome);
  }
}

CacScannerStrategy createCacScanner() => AndroidCacScanner();
