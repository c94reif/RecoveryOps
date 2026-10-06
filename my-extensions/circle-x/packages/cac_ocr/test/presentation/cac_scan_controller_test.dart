import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';
import 'package:cac_ocr/testing.dart';

class _RefusingCancelScanner extends HangingCacScanner {
  @override
  Future<void> cancel() async => throw StateError('camera already gone');
}

void main() {
  CacScanController controllerFor(CacScannerStrategy scanner) =>
      CacScanController(
        cacScanner: scanner,
        verifyOperatorIdentity: VerifyOperatorIdentity(
          scanner: scanner,
          parseBarcode: ParseCacBarcode(() => DateTime.utc(2026, 3, 24, 9)),
        ),
      );

  group('a finished scan', () {
    test('a read card is the last scan and clears the attempt count', () async {
      final scanner = FakeCacScanner()..willFail(CacRejection.noCodeFound);
      final controller = controllerFor(scanner);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.scan();
      expect(controller.scanAttempts, 1);
      scanner.willReadBarcode(cacBarcode());
      await controller.scan();

      expect(controller.lastScan!.identity!.lastName, 'SMITH');
      expect(controller.scanAttempts, 0);
      expect(controller.isScanning, isFalse);
      expect(notifications, 4, reason: 'start and finish of each scan');
    });

    test('each refusal in a row is another attempt', () async {
      final scanner = FakeCacScanner()..willFail(CacRejection.codeUnreadable);
      final controller = controllerFor(scanner);

      await controller.scan();
      await controller.scan();

      expect(controller.scanAttempts, 2);
      expect(controller.lastScan!.rejection, CacRejection.codeUnreadable);
    });

    test('a camera that never came back is not held against the operator',
        () async {
      final scanner = FakeCacScanner()..willFail(CacRejection.cameraTimedOut);
      final controller = controllerFor(scanner);

      await controller.scan();

      expect(controller.scanAttempts, 0);
      expect(controller.lastScan!.rejection, CacRejection.cameraTimedOut);
    });

    test('a scanner that throws reads as no code found, not a crash', () async {
      final scanner = FakeCacScanner()..throwOnCapture = StateError('boom');
      final controller = controllerFor(scanner);

      await controller.scan();

      expect(controller.lastScan!.rejection, CacRejection.noCodeFound);
      expect(controller.isScanning, isFalse);
    });
  });

  group('a scan in flight', () {
    test('asks the scanner only once however often scan is called', () {
      final scanner = HangingCacScanner();
      final controller = controllerFor(scanner);

      controller.scan();
      controller.scan();

      expect(controller.isScanning, isTrue);
      expect(scanner.captureCalls, 1);
    });

    test('cancelling lands on cancelled and rolls back its own attempt',
        () async {
      final scanner = HangingCacScanner();
      final controller = controllerFor(scanner);

      final scan = controller.scan();
      controller.cancelScan();
      scanner.pending.complete(CacCapture.barcode(cacBarcode()));
      await scan;

      expect(scanner.cancelCalls, 1);
      expect(controller.isScanning, isFalse);
      expect(controller.scanAttempts, 0);
      expect(controller.lastScan!.rejection, CacRejection.cancelled,
          reason: 'a card read after the cancel signs nothing');
    });

    test('a scanner that refuses the cancel does not take the caller down',
        () async {
      final controller = controllerFor(_RefusingCancelScanner());

      controller.scan();
      controller.cancelScan();
      await Future<void>.delayed(Duration.zero);

      expect(controller.lastScan!.rejection, CacRejection.cancelled);
    });

    test('reset drops the result of the scan it interrupted', () async {
      final scanner = HangingCacScanner();
      final controller = controllerFor(scanner);

      final scan = controller.scan();
      controller.reset();
      scanner.pending.complete(CacCapture.barcode(cacBarcode()));
      await scan;

      expect(controller.lastScan, isNull);
      expect(controller.isScanning, isFalse);
      expect(controller.scanAttempts, 0);
    });

    test('disposing closes the camera and ignores what arrives later',
        () async {
      final scanner = HangingCacScanner();
      final controller = controllerFor(scanner);

      final scan = controller.scan();
      controller.dispose();
      scanner.pending.complete(CacCapture.barcode(cacBarcode()));
      await scan;

      expect(scanner.cancelCalls, 1);
      await controller.scan();
      expect(scanner.captureCalls, 1, reason: 'a disposed controller is done');
    });
  });

  test('cancelling with nothing in flight changes nothing', () {
    final scanner = FakeCacScanner();
    final controller = controllerFor(scanner);
    var notified = false;
    controller.addListener(() => notified = true);

    controller.cancelScan();

    expect(notified, isFalse);
    expect(controller.lastScan, isNull);
    expect(scanner.cancelCalls, 0);
  });
}
