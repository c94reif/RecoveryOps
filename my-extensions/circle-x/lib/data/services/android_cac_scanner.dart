import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/core/platform/cac_camera_preview.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/usecases/identity/cac_ocr_session.dart';

class AndroidCacScanner implements CacScannerStrategy, CacCameraPreview {
  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);

  @override
  final ValueNotifier<String> guidance = ValueNotifier('');

  @override
  final ValueNotifier<CacScanSide> side = ValueNotifier(CacScanSide.front);

  Completer<CacCapture>? _inFlight;
  CacOcrSession? _session;
  CameraController? _controller;
  TextRecognizer? _recognizer;
  Timer? _timeout;
  bool _frameBusy = false;
  Future<void>? _teardown;

  @override
  Future<bool> isAvailable() async => Platform.isAndroid;

  @override
  Future<CacCapture> capture() async {
    final open = _inFlight;
    if (open != null) return open.future;

    final completer = Completer<CacCapture>();
    _inFlight = completer;
    final session = CacOcrSession();
    _session = session;
    side.value = session.side;
    guidance.value = 'Starting camera…';

    CameraController? initializingController;
    try {
      await _teardown;
      if (_inFlight != completer) return await completer.future;
      final cameras = await availableCameras();
      if (_inFlight != completer) return await completer.future;
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
      initializingController = controller;
      await controller.initialize();
      if (_inFlight != completer) {
        return await completer.future;
      }
      _controller = controller;
      initializingController = null;
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      preview.value = controller;
      guidance.value = session.guidance;

      _startSideTimeout(completer, session);
      await controller.startImageStream(_onFrame);
    } on CameraException catch (error) {
      debugPrint(
          '[CircleX] camera unavailable: ${error.code} ${error.description}');
      if (_inFlight == completer) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
      }
    } catch (error) {
      debugPrint('[CircleX] CAC scanner failed to start: $error');
      if (_inFlight == completer) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
      }
    } finally {
      await initializingController?.dispose();
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _completeCapture(const CacCapture.failed(CacRejection.cancelled));
  }

  Future<void> _onFrame(CameraImage image) async {
    final completer = _inFlight;
    final session = _session;
    final recognizer = _recognizer;
    final controller = _controller;
    if (_frameBusy ||
        completer == null ||
        session == null ||
        recognizer == null ||
        controller == null) {
      return;
    }
    _frameBusy = true;
    try {
      final input = _toInputImage(image, controller.description);
      if (input == null) return;
      final result = await recognizer.processImage(input);
      if (_inFlight != completer) return;

      final lines = <String>[
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ];
      final previousSide = session.side;
      final outcome = session.process(lines);
      side.value = session.side;
      guidance.value = session.guidance;
      if (previousSide != session.side) {
        _startSideTimeout(completer, session);
        unawaited(HapticFeedback.mediumImpact());
      }
      if (outcome != null) {
        unawaited(HapticFeedback.mediumImpact());
        _completeCapture(outcome);
      }
    } catch (error) {
      debugPrint('[CircleX] OCR frame skipped: $error');
    } finally {
      _frameBusy = false;
    }
  }

  void _startSideTimeout(
      Completer<CacCapture> completer, CacOcrSession session) {
    _timeout?.cancel();
    _timeout = Timer(AppConstants.cacCaptureTimeout, () {
      if (_inFlight == completer) {
        _completeCapture(CacCapture.failed(session.timeoutRejection));
      }
    });
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
    _session = null;
    _timeout?.cancel();
    _timeout = null;

    final controller = _controller;
    final recognizer = _recognizer;
    _controller = null;
    _recognizer = null;
    preview.value = null;

    final pendingTeardown = _teardown;
    _teardown = () async {
      await pendingTeardown;
      try {
        if (controller != null) {
          if (controller.value.isStreamingImages) {
            await controller.stopImageStream();
          }
          await controller.dispose();
        }
      } catch (error) {
        debugPrint('[CircleX] camera teardown: $error');
      }
      try {
        await recognizer?.close();
      } catch (error) {
        debugPrint('[CircleX] OCR teardown: $error');
      }
    }();

    if (!completer.isCompleted) completer.complete(outcome);
  }
}

CacScannerStrategy createCacScanner() => AndroidCacScanner();
