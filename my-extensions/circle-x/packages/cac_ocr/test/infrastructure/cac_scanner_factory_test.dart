import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/src/infrastructure/android/android_cac_scanner.dart'
    show AndroidCacScanner;

import '../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an io platform gets the live scanner, available only on Android',
      () async {
    final scanner = createCacScanner();

    expect(scanner, isA<AndroidCacScanner>());
    expect(await scanner.isAvailable(), Platform.isAndroid);
    expect((scanner as AndroidCacScanner).captureTimeout,
        CacScannerStrategy.defaultCaptureTimeout);
    expect(
        (createCacScanner(captureTimeout: const Duration(seconds: 30))
                as AndroidCacScanner)
            .captureTimeout,
        const Duration(seconds: 30));
    expect(scanner.sides, CacSides.frontAndBack);
    expect(
        (createCacScanner(sides: CacSides.backOnly) as AndroidCacScanner).sides,
        CacSides.backOnly);
  });

  test('the unavailable scanner refuses every attempt for want of a camera',
      () async {
    const scanner = UnavailableCacScanner();

    expect(await scanner.isAvailable(), isFalse);
    expect((await scanner.capture()).rejection, CacRejection.noCamera);
    await scanner.cancel();
  });

  group('the capture timeout', () {
    late CacCameraHarness harness;

    setUp(() {
      harness =
          CacCameraHarness(captureTimeout: const Duration(milliseconds: 250))
            ..install();
    });
    tearDown(() => harness.dispose());

    test('names the side it was still waiting on', () async {
      final front = harness.scanner.capture();
      await harness.flush();
      expect((await front).rejection, CacRejection.nameNotFound);

      final back = harness.scanner.capture();
      await harness.flush();
      for (var i = 0; i < CacOcrSession.framesToAgree; i++) {
        await harness.frame(['NAME', 'SMITH, JOHN A']);
      }
      expect(harness.scanner.side.value, CacScanSide.back);
      expect((await back).rejection, CacRejection.noCodeFound);
    });
  });
}
