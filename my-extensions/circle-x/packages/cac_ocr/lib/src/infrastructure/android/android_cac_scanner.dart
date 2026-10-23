import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:cac_ocr/src/infrastructure/camera/cac_camera_geometry.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_camera_preview.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_camera_metering.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_gate.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_quality.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_text.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_read_highlights.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_live_feedback.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_ocr_image.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';
import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';

part 'android_cac_frames.dart';
part 'android_cac_lifecycle.dart';

class AndroidCacScanner extends _CacScannerState
    with WidgetsBindingObserver, _CacFrames, _CacLifecycle {
  AndroidCacScanner({
    super.cameraFactory,
    super.captureTimeout,
    super.sides,
    super.tuning,
    super.diagnostics,
  });

  static const startResolution = ResolutionPreset.veryHigh;
  static const sharperResolution = ResolutionPreset.ultraHigh;
}

abstract class _CacScannerState
    implements CacScannerStrategy, CacCameraPreview, CacLiveFeedback {
  final CameraController Function(CameraDescription, ResolutionPreset)
      _createCamera;
  final Duration captureTimeout;
  @override
  final CacSides sides;

  final CacScanTuning tuning;
  @override
  final CacScanDiagnostics? diagnostics;

  _CacScannerState({
    CameraController Function(CameraDescription, ResolutionPreset)?
        cameraFactory,
    this.captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
    this.sides = CacSides.frontAndBack,
    this.tuning = const CacScanTuning(),
    this.diagnostics,
  })  : _createCamera = cameraFactory ?? _defaultCamera,
        _gate = CacFrameGate(tuning),
        side = ValueNotifier(sides.firstSide);

  static CameraController _defaultCamera(
          CameraDescription camera, ResolutionPreset resolution) =>
      CameraController(camera, resolution,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);

  @override
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);
  @override
  final ValueNotifier<CacGuidance> guidance =
      ValueNotifier(CacInstruction.startingCamera);
  @override
  final ValueNotifier<CacScanSide> side;
  @override
  final ValueNotifier<List<Rect>> highlights = ValueNotifier(const []);
  @override
  final ValueNotifier<bool?> torch = ValueNotifier(false);

  Completer<CacCapture>? _inFlight;
  CacOcrSession? _session;

  CacMetering? _metering;
  CameraController? get _controller => _metering?.camera;
  CacFrameGate _gate;
  CameraDescription? _description;
  ResolutionPreset _resolution = AndroidCacScanner.startResolution;
  TextRecognizer? _recognizer;
  BarcodeScanner? _barcodes;
  Timer? _timeout;
  Future<void>? _processing;
  Future<void>? _startup;
  Future<void>? _focusing;
  Future<void>? _teardown;
  DeviceOrientation? _orientation;
  bool _upgraded = false;
  bool _paused = false;
  int _lifecycleRevision = 0;
  Future<void>? _pausing;
  Future<void>? _reopening;
  int _focusRevision = 0;
  final _elapsed = Stopwatch();

  void _onFrame(CameraImage image);
  void _watchLifecycle();
  void _unwatchLifecycle();

  @override
  Future<bool> isAvailable() async => Platform.isAndroid;

  @override
  Future<CacCapture> capture() {
    final open = _inFlight;
    if (open != null) return open.future;
    final completer = Completer<CacCapture>();
    _inFlight = completer;
    final session = CacOcrSession(sides: sides);
    _session = session;
    _upgraded = false;
    _paused = false;
    diagnostics?.clear();
    _elapsed
      ..reset()
      ..start();
    side.value = session.side;
    guidance.value = CacInstruction.startingCamera;
    _watchLifecycle();
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
      _barcodes =
          BarcodeScanner(formats: [BarcodeFormat.pdf417, BarcodeFormat.code39]);
      await _openCamera(rear, AndroidCacScanner.startResolution, completer);
      if (_inFlight != completer) return;
      guidance.value = session.guidance;
      _startSideTimeout(completer, session);
    } catch (error) {
      debugPrint('[CacOcr] CAC camera unavailable: $error');
      if (_inFlight == completer && !_paused) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
      }
    }
  }

  Future<void> _openCamera(CameraDescription description,
      ResolutionPreset resolution, Completer<CacCapture> completer) async {
    _description = description;
    _resolution = resolution;
    final revision = _lifecycleRevision;
    bool current() =>
        _inFlight == completer && !_paused && revision == _lifecycleRevision;
    final camera = _createCamera(description, resolution);
    var handedOff = false;
    try {
      await camera.initialize();
      if (!current()) return;
      final metering = CacMetering(camera, tuning);
      _metering = metering;
      _gate = CacFrameGate(tuning);
      handedOff = true;
      _orientation = camera.value.deviceOrientation;
      preview.value = camera;
      if (torch.value == true && !await metering.torch(true)) {
        torch.value = null;
      }
      await focusAt(CacCameraGeometry.textTarget(side.value));
      if (!current()) return;
      await camera.startImageStream(_onFrame);
    } finally {
      if (!handedOff) await _disposeCamera(camera);
    }
  }

  @override
  Future<void> focusAt(Offset point) async {
    final metering = _metering;
    if (metering == null ||
        !metering.camera.value.isInitialized ||
        _inFlight == null ||
        _focusing != null) {
      return;
    }
    _session?.resetFrameAgreement();
    _focusRevision++;
    final mapped = CacCameraGeometry.meteringPoint(
        point, CacCameraGeometry.uprightPreview(metering.camera));
    final focusing = metering.focusAt(mapped);
    _focusing = focusing;
    try {
      await focusing;
    } finally {
      _focusing = null;
    }
  }

  @override
  Future<void> setTorch(bool on) async {
    final metering = _metering;
    if (metering == null || torch.value == null) return;
    torch.value = await metering.torch(on) ? on : null;
  }

  @override
  Future<void> cancel() async {
    _completeCapture(const CacCapture.failed(CacRejection.cancelled));
    await _teardown;
  }

  Future<void> _upgradeCamera(CameraController camera,
      Completer<CacCapture> completer, CacOcrSession session) async {
    _upgraded = true;
    _resolution = AndroidCacScanner.sharperResolution;
    session.resetFrameAgreement();
    guidance.value = CacInstruction.adjustingCamera;
    _metering = null;
    preview.value = null;
    await _focusing;
    await _disposeCamera(camera);
    if (_inFlight != completer || _paused) return;
    try {
      await _openAtOrBelow(camera.description, _resolution, completer);
    } catch (error) {
      debugPrint('[CacOcr] camera recovery failed: $error');
      if (_inFlight == completer && !_paused) {
        _completeCapture(const CacCapture.failed(CacRejection.noCamera));
      }
    }
    if (_inFlight == completer) guidance.value = session.guidance;
  }

  Future<void> _openAtOrBelow(CameraDescription description,
      ResolutionPreset resolution, Completer<CacCapture> completer) async {
    try {
      await _openCamera(description, resolution, completer);
    } catch (error) {
      if (resolution == AndroidCacScanner.startResolution) rethrow;
      debugPrint('[CacOcr] sharper camera unavailable: $error');
      if (_inFlight != completer || _paused) return;
      final failedCamera = _controller;
      _metering = null;
      preview.value = null;
      await _disposeCamera(failedCamera);
      if (_inFlight != completer || _paused) return;
      await _openCamera(
          description, AndroidCacScanner.startResolution, completer);
    }
  }

  void _startSideTimeout(
      Completer<CacCapture> completer, CacOcrSession session) {
    _timeout?.cancel();
    if (_paused) return;
    _timeout = Timer(captureTimeout, () {
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
      debugPrint('[CacOcr] camera stream teardown: $error');
    }
    try {
      await camera?.dispose();
    } catch (error) {
      debugPrint('[CacOcr] camera teardown: $error');
    }
  }

  void _completeCapture(CacCapture outcome) {
    final completer = _inFlight;
    if (completer == null) return;
    _inFlight = null;
    _session = null;
    _unwatchLifecycle();
    _elapsed.stop();
    _timeout?.cancel();
    _timeout = null;
    final camera = _controller;
    final recognizer = _recognizer;
    final barcodes = _barcodes;
    final startup = _startup;
    final processing = _processing;
    final focusing = _focusing;
    final pausing = _pausing;
    final reopening = _reopening;
    final previousTeardown = _teardown;
    _metering = null;
    _recognizer = null;
    _barcodes = null;
    preview.value = null;
    highlights.value = const [];
    if (torch.value == true) torch.value = false;
    _teardown = () async {
      await previousTeardown;
      await startup;
      await processing;
      await focusing;
      await pausing;
      await reopening;
      await _disposeCamera(camera);
      try {
        await recognizer?.close();
      } catch (error) {
        debugPrint('[CacOcr] OCR teardown: $error');
      }
      try {
        await barcodes?.close();
      } catch (error) {
        debugPrint('[CacOcr] barcode teardown: $error');
      }
    }();
    if (!completer.isCompleted) completer.complete(outcome);
  }
}

CacScannerStrategy createCacScanner({
  Duration captureTimeout = CacScannerStrategy.defaultCaptureTimeout,
  CacSides sides = CacSides.frontAndBack,
  CacScanDiagnostics? diagnostics,
  CacScanTuning tuning = const CacScanTuning(),
}) =>
    AndroidCacScanner(
        captureTimeout: captureTimeout,
        sides: sides,
        diagnostics: diagnostics,
        tuning: tuning);
