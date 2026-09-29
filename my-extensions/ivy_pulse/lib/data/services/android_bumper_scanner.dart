import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ivy_pulse/core/platform/ocr_camera_preview.dart';
import 'package:ivy_pulse/domain/services/bumper_scanner_strategy.dart';

class AndroidBumperScanner implements BumperScannerStrategy, OcrCameraPreview {
  final CameraController Function(CameraDescription) _createCamera;

  AndroidBumperScanner(
      {CameraController Function(CameraDescription)? cameraFactory})
      : _createCamera = cameraFactory ?? _defaultCamera;

  static CameraController _defaultCamera(CameraDescription description) =>
      CameraController(description, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);

  CameraController? _camera;
  TextRecognizer? _recognizer;
  Completer<List<String>>? _pending;
  Future<void>? _processing;
  Future<void>? _closing;
  Timer? _timeout;
  int _generation = 0;
  bool _disposed = false;
  bool _previewDisposed = false;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<void> start() async {
    if (_disposed || !isSupported) throw BumperScanFailure.unavailable;
    if (_camera != null) return;
    final generation = ++_generation;
    await _closing;
    CameraController? camera;
    var handedOff = false;
    try {
      if (generation != _generation) return;
      final cameras = await availableCameras();
      if (generation != _generation) return;
      if (cameras.isEmpty) throw BumperScanFailure.unavailable;
      final rear = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      camera = _createCamera(rear);
      await camera.initialize();
      if (generation != _generation) return;
      _camera = camera;
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      handedOff = true;
      preview.value = camera;
      await camera.startImageStream(_onFrame);
    } catch (error) {
      if (generation == _generation) await stop();
      debugPrint('[IvyPulse] bumper camera unavailable: $error');
      throw BumperScanFailure.unavailable;
    } finally {
      if (!handedOff) await camera?.dispose();
    }
  }

  @override
  Future<List<String>> read() {
    if (_disposed || _camera == null) {
      return Future.error(BumperScanFailure.unavailable);
    }
    final pending = _pending;
    if (pending != null) return pending.future;
    final request = Completer<List<String>>();
    _pending = request;
    _timeout = Timer(const Duration(seconds: 15), () {
      if (_pending != request) return;
      _pending = null;
      request.completeError(BumperScanFailure.timedOut);
    });
    return request.future;
  }

  void _onFrame(CameraImage frame) {
    final request = _pending;
    final camera = _camera;
    final recognizer = _recognizer;
    // No OCR work is performed until the operator taps Read markings.
    if (request == null ||
        camera == null ||
        recognizer == null ||
        _processing != null) {
      return;
    }
    final input = _inputImage(frame, camera);
    if (input == null) return;
    _processing = _recognize(input, recognizer, request).whenComplete(() {
      _processing = null;
    });
  }

  Future<void> _recognize(InputImage input, TextRecognizer recognizer,
      Completer<List<String>> request) async {
    try {
      final text = await recognizer.processImage(input);
      if (_pending != request) return;
      _pending = null;
      _timeout?.cancel();
      request.complete([
        for (final block in text.blocks)
          for (final line in block.lines) line.text,
      ]);
    } catch (error) {
      if (_pending != request) return;
      _pending = null;
      _timeout?.cancel();
      request.completeError(BumperScanFailure.unreadable);
    }
  }

  InputImage? _inputImage(CameraImage frame, CameraController camera) {
    if (frame.planes.length != 1 ||
        InputImageFormatValue.fromRawValue(frame.format.raw) !=
            InputImageFormat.nv21) {
      return null;
    }
    final deviceRotation = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final description = camera.description;
    final angle = description.lensDirection == CameraLensDirection.front
        ? (description.sensorOrientation + deviceRotation) % 360
        : (description.sensorOrientation - deviceRotation + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(angle);
    if (rotation == null) return null;
    return InputImage.fromBytes(
      bytes: frame.planes.single.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.planes.single.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> stop() {
    if (_previewDisposed) return _closing ?? Future.value();
    _generation++;
    _timeout?.cancel();
    final pending = _pending;
    _pending = null;
    pending?.completeError(BumperScanFailure.cancelled);
    final camera = _camera;
    final recognizer = _recognizer;
    final processing = _processing;
    final closing = _closing;
    _camera = null;
    _recognizer = null;
    preview.value = null;
    return _closing = () async {
      await closing;
      try {
        if (camera?.value.isStreamingImages == true) {
          await camera!.stopImageStream();
        }
      } catch (error) {
        debugPrint('[IvyPulse] bumper stream teardown: $error');
      }
      try {
        await camera?.dispose();
      } catch (error) {
        debugPrint('[IvyPulse] bumper camera teardown: $error');
      }
      await processing;
      try {
        await recognizer?.close();
      } catch (error) {
        debugPrint('[IvyPulse] bumper OCR teardown: $error');
      }
    }();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    _previewDisposed = true;
    preview.dispose();
  }
}

BumperScannerStrategy createBumperScanner() => AndroidBumperScanner();
