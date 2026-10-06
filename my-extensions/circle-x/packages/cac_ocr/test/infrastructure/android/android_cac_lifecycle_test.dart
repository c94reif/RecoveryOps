import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/testing.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';

import '../../support/cac_camera_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacCameraHarness harness;
  const back = CacCameraHarness.cardBack;
  const agree = CacOcrSession.framesToAgree;

  setUp(() {
    harness = CacCameraHarness()..install();
  });
  tearDown(() => harness.dispose());

  int disposals() =>
      harness.cameraCalls.where((call) => call.method == 'dispose').length;

  test('leaving gives the camera back, and returning keeps the name read',
      () async {
    final capture = harness.scanner.capture();
    var completed = false;
    capture.then((_) => completed = true);
    await harness.flush();
    await harness.readFront();
    await harness.frames(back, agree - 1);

    await harness.lifecycle(AppLifecycleState.paused);
    expect(harness.scanner.preview.value, isNull);
    expect(disposals(), 1);
    final runs = harness.ocrRuns;
    await harness.frame(back);
    expect(harness.ocrRuns, runs, reason: 'nothing is read while away');

    await harness.lifecycle(AppLifecycleState.resumed);
    expect(harness.cameras, hasLength(2));
    expect(harness.resolutions.toSet(), hasLength(1),
        reason: 'the same camera, at the same resolution');
    expect(harness.scanner.preview.value, same(harness.cameras.last));
    expect(harness.scanner.side.value, CacScanSide.back);
    expect(harness.scanner.guidance.value.message, contains('SMITH, JOHN A'));

    await harness.frames(back, agree - 1);
    expect(completed, isFalse, reason: 'a new camera starts the count over');
    await harness.frame(back);
    final result = await capture;
    expect(result.asFields.dodId, '1087987498');
    expect(result.asFields.name!.lastName, 'SMITH');
  });

  test('a reopened camera is judged against its own frames', () async {
    harness.scanner.capture();
    await harness.flush();
    await harness.frame(const [], luma: CacCameraHarness.checkerboard());
    await harness.lifecycle(AppLifecycleState.paused);
    await harness.lifecycle(AppLifecycleState.resumed);
    final runs = harness.ocrRuns;

    await harness
        .frame(const [], luma: CacCameraHarness.checkerboard(light: 100));
    expect(harness.ocrRuns, runs + 1,
        reason: 'half as sharp as the last camera is not blurred for this one');
  });

  test('a prompt over the app, which leaves it on screen, keeps the camera',
      () async {
    harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.inactive);
    expect(harness.scanner.preview.value, isNotNull);

    await harness.lifecycle(AppLifecycleState.resumed);
    expect(harness.cameras, hasLength(1));
    expect(disposals(), 0);
  });

  test('a quick away-and-back while the camera starts opens one camera',
      () async {
    harness.pendingInitialize = Completer();
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    await harness.lifecycle(AppLifecycleState.resumed);
    harness.pendingInitialize!.complete();
    await harness.flush();

    expect(harness.cameras, hasLength(2));
    expect(disposals(), 1, reason: 'the camera opened before leaving');
    expect(harness.scanner.preview.value, same(harness.cameras.last));
    await harness.readFront();
    await harness.frames(back, agree);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('away and back again while the camera reopens opens one camera',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    harness.pendingInitialize = Completer();
    await harness.lifecycle(AppLifecycleState.resumed);
    await harness.lifecycle(AppLifecycleState.paused);
    await harness.lifecycle(AppLifecycleState.resumed);
    harness.pendingInitialize!.complete();
    await harness.flush();

    expect(harness.cameras, hasLength(3));
    expect(disposals(), 2, reason: 'the first camera, and the outdated one');
    expect(harness.scanner.preview.value, same(harness.cameras.last));
    await harness.readFront();
    await harness.frames(back, agree);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('a return before the camera has closed waits for it', () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.frames(CacCameraHarness.cardFront, agree - 1);
    harness.pendingOcr = Completer();
    await harness.frame(CacCameraHarness.cardFront);
    await harness.lifecycle(AppLifecycleState.paused);
    await harness.lifecycle(AppLifecycleState.resumed);
    harness.pendingOcr!
        .complete(CacCameraHarness.recognized(CacCameraHarness.cardFront));
    harness.pendingOcr = null;
    await harness.flush();

    expect(harness.cameras, hasLength(2));
    expect(harness.scanner.preview.value, same(harness.cameras.last));
    expect(harness.scanner.side.value, CacScanSide.front,
        reason: 'the frame read before leaving is not counted');
    expect(harness.scanner.guidance.value.message, contains('FRONT'));
    await harness.readFront();
    await harness.frames(back, agree);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('a camera lost to the app leaving is opened again on its return',
      () async {
    harness.pendingInitialize = Completer();
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    harness.failInitialize = true;
    harness.pendingInitialize!.complete();
    await harness.flush();
    harness.failInitialize = false;
    await harness.lifecycle(AppLifecycleState.resumed);

    expect(harness.scanner.preview.value, same(harness.cameras.last));
    await harness.readFront();
    await harness.frames(back, agree);
    expect((await capture).asFields.dodId, '1087987498');
  });

  test('a scan cancelled while the camera reopens lets it close first',
      () async {
    final first = harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    harness.pendingInitialize = Completer();
    await harness.lifecycle(AppLifecycleState.resumed);
    final closing = harness.scanner.cancel();
    final retry = harness.scanner.capture();
    await harness.flush();
    expect((await first).rejection, CacRejection.cancelled);
    harness.pendingInitialize!.complete();
    await closing;
    await harness.flush();

    expect(harness.scanner.preview.value, same(harness.cameras.last));
    await harness.readFront();
    await harness.frames(back, agree);
    expect((await retry).asFields.dodId, '1087987498');
  });

  test('a camera that will not open, with the app in view, ends the scan',
      () async {
    harness.failCreate = true;
    expect((await harness.scanner.capture()).rejection, CacRejection.noCamera);
  });

  test('a camera that does not come back ends the scan, worth a retry',
      () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    harness.failCreate = true;
    await harness.lifecycle(AppLifecycleState.resumed);

    final result = await capture;
    expect(result.rejection, CacRejection.cameraTimedOut);
    expect(result.rejection!.isWorthRetrying, isTrue);
  });

  test('the time limit waits while away, and starts over on return', () async {
    await harness.dispose();
    harness =
        CacCameraHarness(captureTimeout: const Duration(milliseconds: 200))
          ..install();
    var result = Completer<CacCapture>();
    harness.scanner.capture().then(result.complete);
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(result.isCompleted, isFalse);

    await harness.lifecycle(AppLifecycleState.resumed);
    expect(result.isCompleted, isFalse);
    expect((await result.future).rejection, CacRejection.nameNotFound);
  });

  test('a camera that comes up while away waits for the return', () async {
    await harness.dispose();
    harness =
        CacCameraHarness(captureTimeout: const Duration(milliseconds: 200))
          ..install();
    harness.pendingInitialize = Completer();
    final result = Completer<CacCapture>();
    harness.scanner.capture().then(result.complete);
    await harness.flush();
    await harness.lifecycle(AppLifecycleState.paused);
    harness.pendingInitialize!.complete();
    await harness.flush();
    expect(harness.scanner.preview.value, isNull,
        reason: 'let go without being shown');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(result.isCompleted, isFalse, reason: 'no time limit while away');

    await harness.lifecycle(AppLifecycleState.resumed);
    expect(harness.cameras, hasLength(2));
    expect(harness.scanner.preview.value, same(harness.cameras.last));
    expect((await result.future).rejection, CacRejection.nameNotFound);
  });

  test('a finished scan no longer follows the app', () async {
    final capture = harness.scanner.capture();
    await harness.flush();
    await harness.readFront();
    await harness.frames(back, agree);
    await capture;

    await harness.lifecycle(AppLifecycleState.paused);
    await harness.lifecycle(AppLifecycleState.resumed);
    expect(harness.cameras, hasLength(1));
  });
}
