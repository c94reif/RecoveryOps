import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/testing.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';

import 'package:cac_ocr/src/infrastructure/camera/cac_scan_tuning.dart';

import '../../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacCameraHarness harness;
  const tuning = CacScanTuning();
  const front = CacCameraHarness.cardFront;
  const back = CacCameraHarness.cardBack;
  const agree = CacOcrSession.framesToAgree;

  setUp(() {
    harness = CacCameraHarness()..install();
  });
  tearDown(() => harness.dispose());

  Future<void> start() async {
    harness.scanner.capture();
    await harness.flush();
  }

  List<Object?> offsets() => [
        for (final call in harness.cameraCalls)
          if (call.method == 'setExposureOffset')
            (call.arguments as Map)['offset'],
      ];

  group('focus and exposure', () {
    test('hold once the name is found, and only then', () async {
      await start();
      await harness.frame(const []);
      expect(harness.modes('setFocusMode'), ['auto'],
          reason: 'nothing on the card to hold on yet');

      await harness.frame(front);
      expect(harness.modes('setFocusMode'), ['auto', 'locked']);
      expect(harness.modes('setExposureMode'), ['auto', 'locked']);
      await harness.frame(front);
      expect(harness.modes('setFocusMode'), ['auto', 'locked']);
    });

    test('blurred frames in a row let go, to focus again', () async {
      final sharp = CacCameraHarness.checkerboard();
      final soft = Uint8List(640 * 480);
      await start();
      await harness.frame(front, luma: sharp);
      expect(harness.modes('setFocusMode').last, 'locked');

      final almost = tuning.softFramesBeforeRefocus - 1;
      await harness.frames(front, almost, luma: soft);
      await harness.frame(front, luma: sharp);
      await harness.frames(front, almost, luma: soft);
      expect(harness.modes('setFocusMode').last, 'locked',
          reason: 'soft moments between sharp frames are not a moved card');
      await harness.frame(front, luma: soft);
      expect(harness.modes('setFocusMode').last, 'auto');

      await harness.frame(front, luma: sharp);
      expect(harness.modes('setFocusMode').last, 'locked');
    });

    test('blur with nothing held leaves the camera to its own focus', () async {
      await start();
      await harness.frame(const [], luma: CacCameraHarness.checkerboard());
      await harness.frames(const [], tuning.softFramesBeforeRefocus + 1,
          luma: Uint8List(640 * 480));
      expect(harness.modes('setFocusMode'), ['auto'],
          reason: 'no card was found, so there was no hold to let go');
    });

    test('a flip lets go for the back, which is not in view yet', () async {
      await start();
      await harness.readFront();
      expect(harness.modes('setFocusMode').last, 'auto');

      await harness.frame(back);
      expect(harness.modes('setFocusMode').last, 'locked');
    });

    test('a camera that cannot hold still scans', () async {
      harness.rejectFocus = true;
      final capture = harness.scanner.capture();
      await harness.flush();
      await harness.readFront();
      await harness.frames(back, agree);
      expect((await capture).asFields.dodId, '1087987498');
    });
  });

  group('torch', () {
    test('turns on and off, and is off once the scan ends', () async {
      final capture = harness.scanner.capture();
      await harness.flush();
      expect(harness.scanner.torch.value, isFalse);

      await harness.scanner.setTorch(true);
      expect(harness.scanner.torch.value, isTrue);
      await harness.scanner.setTorch(false);
      expect(harness.scanner.torch.value, isFalse);
      expect(harness.modes('setFlashMode'), ['torch', 'off']);

      await harness.scanner.setTorch(true);
      await harness.readFront();
      await harness.frames(back, agree);
      await capture;
      expect(harness.scanner.torch.value, isFalse);
    });

    test('a camera without one hides the switch for good', () async {
      harness.torchless = true;
      await start();
      await harness.scanner.setTorch(true);
      expect(harness.scanner.torch.value, isNull);

      await harness.scanner.setTorch(true);
      expect(harness.modes('setFlashMode'), hasLength(1));
    });

    test('stays on when the camera reopens sharper', () async {
      await start();
      await harness.scanner.setTorch(true);
      await harness.readFront();
      await harness.frames(const ['DoD ID Number 108798749'],
          tuning.unreadableFramesBeforeUpgrade);

      expect(harness.resolutions, hasLength(2));
      expect(harness.modes('setFlashMode'), ['torch', 'torch']);
      expect(harness.scanner.torch.value, isTrue);
    });

    test('a sharper camera without one hides the switch', () async {
      await start();
      await harness.scanner.setTorch(true);
      harness.torchless = true;
      await harness.readFront();
      await harness.frames(const ['DoD ID Number 108798749'],
          tuning.unreadableFramesBeforeUpgrade);

      expect(harness.resolutions, hasLength(2));
      expect(harness.scanner.torch.value, isNull);
    });

    test('does nothing before the camera is up', () async {
      await harness.scanner.setTorch(true);
      expect(harness.modes('setFlashMode'), isEmpty);
      expect(harness.scanner.torch.value, isFalse);
    });
  });

  test('a camera that cannot reopen at any resolution ends the scan', () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.readFront();
    harness.failCreate = true;
    await harness.frames(const ['DoD ID Number 108798749'],
        tuning.unreadableFramesBeforeUpgrade);

    expect((await capture).rejection, CacRejection.noCamera);
    expect(harness.scanner.preview.value, isNull);
  });

  group('glare', () {
    Uint8List glary() =>
        CacCameraHarness.checkerboard()..fillRange(640 * 220, 640 * 260, 255);

    test('dims the exposure a stop, once for the camera', () async {
      await start();
      await harness.frame(front, luma: CacCameraHarness.checkerboard());
      expect(offsets(), isEmpty);

      await harness.frame(const [], luma: glary());
      expect(offsets(), [tuning.glareExposureOffset]);
      await harness.frame(const [], luma: glary());
      expect(offsets(), hasLength(1));
    });

    test('no further than the camera goes', () async {
      harness.minExposureOffset = -0.5;
      await start();
      await harness.frame(const [], luma: glary());
      expect(offsets(), [-0.5]);
    });
  });
}
