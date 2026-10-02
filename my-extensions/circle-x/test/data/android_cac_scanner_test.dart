import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/services/android_cac_scanner.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';

import '../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacCameraHarness harness;
  const front = ['NAME', 'SMITH, JOHN A', 'RANK', 'SGT'];
  const back = ['DoD ID Number 1087987498'];
  const short = ['DoD ID Number 108798749'];

  setUp(() {
    harness = CacCameraHarness()..install();
  });
  tearDown(() => harness.dispose());

  Future<void> readFront() async {
    await harness.frame(front);
    await harness.frame(front);
    expect(harness.scanner.side.value, CacScanSide.back);
  }

  test('meters each side and sends cropped pixels through two-sided OCR',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    expect(harness.resolutions, [ResolutionPreset.high]);
    final frontPoint = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(frontPoint['y'], greaterThan(0.5));
    await readFront();
    final backPoint = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(backPoint['y'], lessThan(0.5));
    final inputs = harness.ocrCalls
        .where((call) => call.method == 'vision#startTextRecognizer');
    final metadata = inputs.first.arguments['imageData']['metadata'] as Map;
    expect(metadata['rotation'], 90);
    expect(metadata['width'], lessThan(640));
    expect(metadata['height'], lessThan(480));
    await harness.frame(back);
    await harness.frame(back);
    final result = await capture;
    expect(result.barcode, '1087987498');
    expect(result.name!.lastName, 'SMITH');
    await harness.scanner.cancel();
    expect(harness.ocrCalls.last.method, 'vision#closeTextRecognizer');
  });

  test('rotation remeters, updates OCR rotation and resets agreement',
      () async {
    final capture = harness.scanner.capture();
    var completed = false;
    capture.then((_) => completed = true);
    await harness.flush();
    await readFront();
    await harness.frame(back);
    await harness.rotate('landscapeLeft');
    await harness.frame(back); // Refocus after rotating, before using frames.
    await harness.frame(back);
    expect(completed, isFalse);
    final input = harness.ocrCalls.last.arguments['imageData'] as Map;
    expect(input['metadata']['rotation'], 0);
    await harness.frame(back);
    expect((await capture).barcode, '1087987498');
  });

  test('tap-to-focus maps visible coordinates and discards older OCR',
      () async {
    final capture = harness.scanner.capture();
    var completed = false;
    capture.then((_) => completed = true);
    await harness.flush();
    await readFront();
    harness.pendingOcr = Completer();
    await harness.frame(back);
    await harness.scanner.focusAt(const Offset(0.25, 0.25));
    final point = harness.cameraCalls
        .lastWhere((call) => call.method == 'setFocusPoint')
        .arguments as Map;
    expect(point['x'], 0.25);
    // The portrait preview is cropped vertically to fit the 4:3 viewfinder.
    expect(point['y'], closeTo(0.359375, 0.00001));
    harness.pendingOcr!.complete(CacCameraHarness.recognized(back));
    await harness.flush();
    harness.pendingOcr = null;
    await harness.frame(back);
    expect(completed, isFalse);
    await harness.frame(back);
    expect((await capture).barcode, '1087987498');
  });

  for (final rejectPreset in [false, true]) {
    test('repeated short reads retry sharper capture (fallback: $rejectPreset)',
        () async {
      harness.rejectHigherResolution = rejectPreset;
      final capture = harness.scanner.capture();
      await harness.flush();
      await readFront();
      for (var i = 0;
          i < AndroidCacScanner.unreadableFramesBeforeUpgrade;
          i++) {
        await harness.frame(short);
      }
      expect(harness.resolutions, [
        ResolutionPreset.high,
        ResolutionPreset.veryHigh,
        if (rejectPreset) ResolutionPreset.high,
      ]);
      expect(harness.scanner.side.value, CacScanSide.back);
      // This attempt must not reopen the camera on every failed frame.
      for (var i = 0;
          i < AndroidCacScanner.unreadableFramesBeforeUpgrade;
          i++) {
        await harness.frame(short);
      }
      expect(harness.resolutions.length, rejectPreset ? 3 : 2);
      await harness.frame(back);
      await harness.frame(back);
      final result = await capture;
      expect(result.barcode, '1087987498');
      expect(result.name!.lastName, 'SMITH');
    });
  }

  test('unsupported focus controls still allow OCR and exposure metering',
      () async {
    harness.rejectFocus = true;
    final capture = harness.scanner.capture();
    await harness.flush();
    expect(harness.cameraCalls.map((call) => call.method),
        contains('setExposurePoint'));
    await readFront();
    await harness.frame(back);
    await harness.frame(back);
    expect((await capture).barcode, '1087987498');
  });

  test('fixed-focus cameras skip unsupported metering points', () async {
    harness.supportsMetering = false;
    harness.scanner.capture();
    await harness.flush();
    expect(harness.cameraCalls.map((call) => call.method),
        isNot(contains('setFocusPoint')));
    expect(harness.cameraCalls.map((call) => call.method),
        isNot(contains('setExposurePoint')));
  });

  test('cancelled OCR drains before a fresh attempt and cannot reuse a name',
      () async {
    final first = harness.scanner.capture();
    await harness.flush();
    await readFront();
    harness.pendingOcr = Completer();
    await harness.frame(back);
    final closing = harness.scanner.cancel();
    final retry = harness.scanner.capture();
    await harness.flush();
    expect(harness.resolutions, [ResolutionPreset.high]);
    expect((await first).rejection, CacRejection.cancelled);
    expect(harness.ocrCalls.map((call) => call.method),
        isNot(contains('vision#closeTextRecognizer')));
    harness.pendingOcr!.complete(CacCameraHarness.recognized(back));
    await closing;
    harness.pendingOcr = null;
    await harness.flush();
    expect(harness.scanner.side.value, CacScanSide.front);
    await readFront();
    await harness.frame(back);
    await harness.frame(back);
    expect((await retry).barcode, '1087987498');
  });

  test(
      'cancellation during higher-resolution initialization releases the camera',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await readFront();
    harness.pendingInitialize = Completer();
    for (var i = 0; i < AndroidCacScanner.unreadableFramesBeforeUpgrade; i++) {
      await harness.frame(short);
    }
    expect(harness.resolutions,
        [ResolutionPreset.high, ResolutionPreset.veryHigh]);
    final closing = harness.scanner.cancel();
    expect((await capture).rejection, CacRejection.cancelled);
    harness.pendingInitialize!.complete();
    await closing;
    expect(harness.scanner.preview.value, isNull);
    expect(harness.cameraCalls.where((call) => call.method == 'dispose'),
        hasLength(2));
  });
}
