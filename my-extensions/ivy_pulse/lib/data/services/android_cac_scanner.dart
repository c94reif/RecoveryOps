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

/// Reads the DoD ID number off the back of a CAC with the device camera, by
/// OCR, from a live preview — the Android path.
///
/// Compiled into the host natively this has what the WebView never did: a
/// camera stream and Android's on-device text recognition. So instead of one
/// blind photograph judged after the fact, the operator sees the card in a
/// viewfinder and the number is read the moment it is legible — no shutter,
/// no "did that take". Frames are fed to ML Kit as they arrive, throttled to
/// one at a time; the first ten-digit DoD ID that two consecutive frames
/// agree on ends the scan. Two, because OCR on a moving card will misread a
/// single digit for a single frame, and a wrong number that looks right is
/// the worst outcome this file can produce.
///
/// Nothing is stored. Frames live in the camera buffer and the recogniser
/// and are gone when the next one arrives; no image is written, kept, or
/// attached. The recogniser sees the whole back of the card — including the
/// date of birth printed there — and [findDodId] picks out the ID number and
/// drops the rest on the floor, the same way the barcode parser always did.
///
/// A scan can end four ways: a read, the operator cancelling, the hard
/// timeout in [AppConstants.cacCaptureTimeout] expiring with nothing found,
/// or the camera refusing to open — permission denied, in use, absent.
class AndroidCacScanner implements CacScannerStrategy {
  /// The live controller while a scan is running, for the viewfinder to
  /// render. Null between scans.
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);

  /// What the operator is told beneath the viewfinder — where in the read
  /// things are, so a card that is not reading gets moved rather than held.
  final ValueNotifier<String> guidance = ValueNotifier('');

  /// Agreeing frames needed before a number is trusted.
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
    // A second call while one is open joins it rather than fighting it for
    // the camera.
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
        _finish(const CacCapture.failed(CacRejection.noCamera));
        return await completer.future;
      }
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        // The one format ML Kit takes from Android as a single plane.
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      // Requests the runtime permission on first use; a refusal throws.
      await controller.initialize();
      if (_inFlight != completer) {
        // Cancelled while the camera was opening.
        await controller.dispose();
        return await completer.future;
      }
      _controller = controller;
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      preview.value = controller;
      guidance.value = 'Fill the box with the BACK of the card';

      _timeout = Timer(AppConstants.cacCaptureTimeout, () {
        _finish(const CacCapture.failed(CacRejection.noCodeFound));
      });
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      debugPrint('[IvyPulse] camera unavailable: ${e.code} ${e.description}');
      _finish(const CacCapture.failed(CacRejection.noCamera));
    } catch (e) {
      debugPrint('[IvyPulse] CAC scanner failed to start: $e');
      _finish(const CacCapture.failed(CacRejection.noCamera));
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _finish(const CacCapture.failed(CacRejection.cancelled));
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
        _finish(CacCapture.read(found));
      } else {
        guidance.value = 'Almost — hold still';
      }
    } catch (e) {
      // One bad frame is not a failed scan; the next one is already coming.
      debugPrint('[IvyPulse] OCR frame skipped: $e');
    } finally {
      _frameBusy = false;
    }
  }

  /// Wraps a camera frame for ML Kit without copying it.
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

  /// Ends the scan exactly once and gives the camera back. Safe to call from
  /// any path, including a cancel that lands while the camera is opening.
  void _finish(CacCapture outcome) {
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
      } catch (e) {
        debugPrint('[IvyPulse] camera teardown: $e');
      }
      await recognizer?.close();
    }());

    if (!completer.isCompleted) completer.complete(outcome);
  }
}

CacScannerStrategy createCacScanner() => AndroidCacScanner();
