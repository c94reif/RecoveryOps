import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:circle_x/core/constants/app_constants.dart';
import 'package:circle_x/core/platform/cac_camera_geometry.dart';
import 'package:circle_x/core/platform/cac_camera_preview.dart';
import 'package:circle_x/data/services/cac_camera_focus.dart';
import 'package:circle_x/data/services/cac_ocr_image.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/usecases/identity/cac_ocr_session.dart';

class AndroidCacScanner implements CacScannerStrategy, CacCameraPreview {
  final CameraController Function(CameraDescription, ResolutionPreset)
      _createCamera;

  AndroidCacScanner({
    CameraController Function(CameraDescription, ResolutionPreset)?
        cameraFactory,
  }) : _createCamera = cameraFactory ?? _defaultCamera;

  static const unreadableFramesBeforeUpgrade = 12;

  static CameraController _defaultCamera(
          CameraDescription camera, ResolutionPreset resolution) =>
      CameraController(camera, resolution,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

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
  Future<void>? _processing;
  Future<void>? _startup;
  Future<void>? _focusing;
  Future<void>? _teardown;
  DeviceOrientation? _orientation;
  bool _upgraded = false;
  int _focusRevision = 0;

  @override
  Future<bool> isAvailable() async => Platform.isAndroid;

  @override
  Future<CacCapture> capture() {
    final open = _inFlight;
    if (open != null) return open.future;
    final completer = Completer<CacCapture>();
    _inFlight = completer;
    final session = CacOcrSession();
    _session = session;
    _upgraded = false;
    side.value = session.side;
    guidance.value = 'Starting camera…';
    _startup = _startCapture(completer, session, _teardown);
    return completer.future;
  }

  Future<void> _startCapture(Completer<CacCapture> completer,
      CacOcrSession session, Future<void>? previousTeardown) async {
    try {
      await previousTeardown;
      if (_inFlight != completer) return;
      final cameras = await availableCameras();
      if (_inFlight != completer) return;
      if (cameras.isEmpty) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
        return;
      }
      final rear = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      await _openCamera(rear, ResolutionPreset.high, completer);
      if (_inFlight != completer) return;
      guidance.value = session.guidance;
      _startSideTimeout(completer, session);
    } catch (error) {
      debugPrint('[CircleX] CAC camera unavailable: $error');
      if (_inFlight == completer) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
      }
    }
  }

  Future<void> _openCamera(CameraDescription description,
      ResolutionPreset resolution, Completer<CacCapture> completer) async {
    final camera = _createCamera(description, resolution);
    var handedOff = false;
    try {
      await camera.initialize();
      if (_inFlight != completer) return;
      _controller = camera;
      handedOff = true;
      _orientation = camera.value.deviceOrientation;
      preview.value = camera;
      await focusAt(CacCameraGeometry.textTarget(side.value));
      if (_inFlight != completer) return;
      await camera.startImageStream(_onFrame);
    } finally {
      if (!handedOff) await _disposeCamera(camera);
    }
  }

  @override
  Future<void> focusAt(Offset point) async {
    final camera = _controller;
    if (camera == null ||
        !camera.value.isInitialized ||
        _inFlight == null ||
        _focusing != null) {
      return;
    }
    _session?.resetFrameAgreement();
    _focusRevision++;
    final mapped = CacCameraGeometry.meteringPoint(
        point, CacCameraGeometry.uprightPreview(camera));
    final focusing = focusCacCamera(camera, mapped);
    _focusing = focusing;
    try {
      await focusing;
    } finally {
      _focusing = null;
    }
  }

  @override
  Future<void> cancel() async {
    _completeCapture(const CacCapture.failed(CacRejection.cancelled));
    await _teardown;
  }

  void _onFrame(CameraImage image) {
    final completer = _inFlight;
    final session = _session;
    final recognizer = _recognizer;
    final camera = _controller;
    if (_processing != null ||
        _focusing != null ||
        completer == null ||
        session == null ||
        recognizer == null ||
        camera == null) {
      return;
    }
    _processing = _processFrame(image, camera, recognizer, session, completer)
        .whenComplete(() => _processing = null);
  }

  Future<void> _processFrame(
      CameraImage image,
      CameraController camera,
      TextRecognizer recognizer,
      CacOcrSession session,
      Completer<CacCapture> completer) async {
    try {
      final orientation = camera.value.deviceOrientation;
      final focusRevision = _focusRevision;
      if (_orientation != orientation) {
        _orientation = orientation;
        await focusAt(CacCameraGeometry.textTarget(session.side));
        return;
      }
      final input =
          cacOcrImage(image, camera.description, orientation, session.side);
      if (input == null) return;
      final result = await recognizer.processImage(input);
      if (_inFlight != completer) return;
      if (focusRevision != _focusRevision) return;
      if (orientation != camera.value.deviceOrientation) {
        session.resetFrameAgreement();
        return;
      }
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
        await focusAt(CacCameraGeometry.textTarget(session.side));
      }
      if (outcome != null) {
        unawaited(HapticFeedback.mediumImpact());
        _completeCapture(outcome);
      } else if (!_upgraded &&
          session.unreadableFrames >= unreadableFramesBeforeUpgrade) {
        await _upgradeCamera(camera, completer, session);
      }
    } catch (error) {
      debugPrint('[CircleX] OCR frame skipped: $error');
    }
  }

  Future<void> _upgradeCamera(CameraController camera,
      Completer<CacCapture> completer, CacOcrSession session) async {
    _upgraded = true;
    session.resetFrameAgreement();
    guidance.value =
        'Adjusting camera for a clearer read — hold the card steady';
    _controller = null;
    preview.value = null;
    await _focusing;
    await _disposeCamera(camera);
    if (_inFlight != completer) return;
    try {
      await _openCamera(
          camera.description, ResolutionPreset.veryHigh, completer);
    } catch (error) {
      debugPrint('[CircleX] sharper camera unavailable: $error');
      if (_inFlight != completer) return;
      final failedCamera = _controller;
      _controller = null;
      preview.value = null;
      await _disposeCamera(failedCamera);
      if (_inFlight != completer) return;
      try {
        // An unsupported preset must not end an otherwise usable scan.
        await _openCamera(camera.description, ResolutionPreset.high, completer);
      } catch (error) {
        debugPrint('[CircleX] camera recovery failed: $error');
        if (_inFlight == completer) {
          _completeCapture(const CacCapture.failed(CacRejection.noCamera));
        }
      }
    }
    if (_inFlight == completer) guidance.value = session.guidance;
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

  Future<void> _disposeCamera(CameraController? camera) async {
    try {
      if (camera?.value.isStreamingImages == true) {
        await camera!.stopImageStream();
      }
    } catch (error) {
      debugPrint('[CircleX] camera stream teardown: $error');
    }
    try {
      await camera?.dispose();
    } catch (error) {
      debugPrint('[CircleX] camera teardown: $error');
    }
  }

  void _completeCapture(CacCapture outcome) {
    final completer = _inFlight;
    if (completer == null) return;
    _inFlight = null;
    _session = null;
    _timeout?.cancel();
    _timeout = null;
    final camera = _controller;
    final recognizer = _recognizer;
    final startup = _startup;
    final processing = _processing;
    final focusing = _focusing;
    final previousTeardown = _teardown;
    _controller = null;
    _recognizer = null;
    preview.value = null;
    _teardown = () async {
      await previousTeardown;
      await startup;
      await processing;
      await focusing;
      await _disposeCamera(camera);
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
