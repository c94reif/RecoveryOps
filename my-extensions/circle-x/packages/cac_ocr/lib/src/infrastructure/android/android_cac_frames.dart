part of 'android_cac_scanner.dart';

mixin _CacFrames on _CacScannerState {
  @override
  void _onFrame(CameraImage image) {
    final completer = _inFlight;
    final session = _session;
    final recognizer = _recognizer;
    final metering = _metering;
    if (_processing != null ||
        _focusing != null ||
        _paused ||
        completer == null ||
        session == null ||
        recognizer == null ||
        metering == null) {
      return;
    }
    _processing = _processFrame(image, metering, recognizer, session, completer)
        .whenComplete(() => _processing = null);
  }

  Future<void> _processFrame(
      CameraImage image,
      CacMetering metering,
      TextRecognizer recognizer,
      CacOcrSession session,
      Completer<CacCapture> completer) async {
    try {
      final camera = metering.camera;
      final gate = _gate;
      final orientation = camera.value.deviceOrientation;
      final focusRevision = _focusRevision;
      final lifecycleRevision = _lifecycleRevision;
      if (_orientation != orientation) {
        _orientation = orientation;
        await focusAt(CacCameraGeometry.textTarget(session.side));
        return;
      }
      final input =
          cacOcrImage(image, camera.description, orientation, session.side);
      if (input == null) return;
      final metadata = input.metadata!;
      final quality = measureCacFrame(input.bytes!, metadata.size.width.toInt(),
          metadata.size.height.toInt());
      final skip = gate.judge(quality);
      if (gate.isGlary(quality)) metering.dimForGlare();
      if (skip != null) {
        _report(session, quality, gate.sharpest, skipped: skip);
        if (skip == CacFrameSkip.glare) {
          guidance.value = CacInstruction.tiltFromGlare;
        } else if (metering.softFrame()) {
          await focusAt(CacCameraGeometry.textTarget(session.side));
        }
        return;
      }
      metering.sharpFrame();
      final started = _elapsed.elapsed;
      final (result, codes) =
          await (recognizer.processImage(input), _readBarcodes(input)).wait;
      final readTime = _elapsed.elapsed - started;
      if (_inFlight != completer) return;
      if (lifecycleRevision != _lifecycleRevision) return;
      if (focusRevision != _focusRevision) return;
      if (orientation != camera.value.deviceOrientation) {
        session.resetFrameAgreement();
        return;
      }
      final text = CacFrameText.of(result,
          tuning: tuning, checkDigits: session.side == CacScanSide.back);
      final found = [
        for (final code in codes)
          if (_cacBarcode(code) case final barcode?)
            (barcode: barcode, box: code.boundingBox),
      ];
      final barcodes = [for (final code in found) code.barcode];
      final previousSide = session.side;
      final outcome = session.process(text.lines, barcodes: barcodes);
      side.value = session.side;
      highlights.value = cacReadHighlights(
        name: session.lastNameRead,
        dodId: session.lastDodIdRead,
        text: text,
        barcodeBoxes: [for (final code in found) code.box],
        metadata: metadata,
      );
      guidance.value = outcome == null && gate.isGlary(quality)
          ? CacInstruction.tiltFromGlare
          : session.guidance;
      _report(session, quality, gate.sharpest,
          text: text, barcodes: barcodes, readTime: readTime);
      if (previousSide != session.side) {
        _startSideTimeout(completer, session);
        unawaited(HapticFeedback.mediumImpact());
        await focusAt(CacCameraGeometry.textTarget(session.side));
      }
      if (outcome != null) {
        unawaited(HapticFeedback.mediumImpact());
        _completeCapture(outcome);
        return;
      }
      if (session.sawCard &&
          previousSide == session.side &&
          _inFlight == completer) {
        await metering.hold();
      }
      if (!_upgraded &&
          session.unreadableFrames >= tuning.unreadableFramesBeforeUpgrade) {
        await _upgradeCamera(camera, completer, session);
      }
    } catch (error) {
      debugPrint('[CacOcr] OCR frame skipped: $error');
    }
  }

  Future<List<Barcode>> _readBarcodes(InputImage input) async {
    final scanner = _barcodes;
    if (scanner == null) return const [];
    try {
      return await scanner.processImage(input);
    } catch (error) {
      debugPrint('[CacOcr] barcode frame skipped: $error');
      return const [];
    }
  }

  static CacBarcode? _cacBarcode(Barcode code) {
    final value = code.rawValue;
    if (value == null || value.isEmpty) return null;
    return switch (code.format) {
      BarcodeFormat.pdf417 => (format: CacBarcodeFormat.pdf417, value: value),
      BarcodeFormat.code39 => (format: CacBarcodeFormat.code39, value: value),
      _ => null,
    };
  }

  void _report(
    CacOcrSession session,
    CacFrameQuality quality,
    double sharpest, {
    CacFrameSkip? skipped,
    CacFrameText? text,
    List<CacBarcode> barcodes = const [],
    Duration? readTime,
  }) {
    final sink = diagnostics;
    if (sink == null) return;
    final name = session.lastNameRead;
    final dodId = session.lastDodIdRead;
    sink.add(CacFrameReport(
      at: _elapsed.elapsed,
      side: session.side,
      sharpness: quality.sharpness,
      sharpest: sharpest,
      glare: quality.glare,
      skipped: skipped,
      linesKept: text?.lines.length ?? 0,
      linesDropped: text?.dropped ?? 0,
      lowestConfidence: text?.lowestConfidence,
      doubtfulDigits: text?.doubtfulDigits ?? 0,
      barcodes: [for (final barcode in barcodes) barcode.format],
      reading: text == null
          ? null
          : dodId != null
              ? 'DoD ID ${CacFrameReport.maskDodId(dodId)}'
              : name != null
                  ? 'name ${CacFrameReport.maskName(name)}'
                  : null,
      backing: session.backing,
      contested: session.contested,
      readTime: readTime,
    ));
  }
}
