import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

import '../support/cac_fixtures.dart';
import '../support/fakes.dart';
import '../support/inspection_harness.dart';

/// The scan-abandonment paths, which only exist because of a latch that shipped
/// once: a capture that never returned left `isScanning` set forever, `scanCac`
/// refused every retry behind its own guard, and the scanning card rendered no
/// controls at all. The view model is a lazy singleton, so the only way out was
/// killing the extension with a walked PMCS inside it.
void main() {
  group('cancelling a scan', () {
    late HangingCacScanner scanner;
    late InspectionHarness harness;
    late InspectionViewModel viewModel;

    setUp(() {
      clearSnackBars();
      scanner = HangingCacScanner();
      harness = InspectionHarness(scanner: scanner);
      viewModel = harness.viewModel;
    });

    /// Starts a scan and leaves it in flight — the camera is open and the
    /// operator is holding a card up.
    Future<void> startScanning() async {
      unawaited(viewModel.scanCac());
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isScanning, isTrue);
    }

    test('a scan in flight leaves the card in its scanning state', () async {
      await startScanning();

      expect(viewModel.scanAttempts, 1);
      expect(viewModel.lastScan, isNull);
      expect(scanner.captureCalls, 1);
    });

    test('cancelling clears the scan and lands on the refused state', () async {
      await startScanning();

      viewModel.cancelScan();

      expect(viewModel.isScanning, isFalse);
      expect(viewModel.lastScan!.rejection, CacRejection.cancelled);
      // The refused card is the destination on purpose: SCAN AGAIN and SUBMIT
      // UNVERIFIED are the two things the operator can actually do, and a
      // fifth sign-off state would have said the same with nothing on it.
      expect(viewModel.canSubmitUnverified, isTrue);
      expect(viewModel.isSignedOff, isFalse);
    });

    test('cancelling tells the scanner, without waiting on it', () async {
      await startScanning();

      viewModel.cancelScan();

      // Synchronous: the operator's panel must not wait on a camera that has
      // already proved it is not answering.
      expect(scanner.cancelCalls, 1);
    });

    test('a cancelled scan can be retried immediately', () async {
      await startScanning();
      viewModel.cancelScan();

      // The whole point. Under the latch this returned at the guard and the
      // operator never got a second camera.
      unawaited(viewModel.scanCac());
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isScanning, isTrue);
      expect(scanner.captureCalls, 2);
    });

    test('a late photo cannot sign a PMCS the operator walked away from',
        () async {
      // The sequence the generation guard exists for, and the one that puts a
      // Soldier's name on a 5988-E they did not sign: the camera is a separate
      // activity that can deliver long after the scan was abandoned.
      await startScanning();
      viewModel.cancelScan();

      scanner.pending.complete(CacCapture.read(cacBarcode()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isSignedOff, isFalse);
      expect(viewModel.lastScan!.rejection, CacRejection.cancelled);
      expect(viewModel.isScanning, isFalse);
    });

    test('a late refusal cannot re-latch the scanning state either', () async {
      await startScanning();
      viewModel.cancelScan();

      scanner.pending
          .complete(const CacCapture.failed(CacRejection.cameraTimedOut));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isScanning, isFalse);
      expect(viewModel.lastScan!.rejection, CacRejection.cancelled,
          reason: 'the abandoned capture overwrote the answer the operator '
              'is looking at');
    });

    test('cancelling with nothing in flight changes nothing', () async {
      viewModel.cancelScan();

      expect(scanner.cancelCalls, 0);
      expect(viewModel.lastScan, isNull);
      expect(viewModel.isScanning, isFalse);
    });

    test('a scanner that throws on cancel does not take the panel with it',
        () async {
      final throwing = ThrowingCancelScanner();
      final own = InspectionHarness(scanner: throwing).viewModel;
      unawaited(own.scanCac());
      await Future<void>.delayed(Duration.zero);

      own.cancelScan();
      await Future<void>.delayed(Duration.zero);

      expect(own.isScanning, isFalse);
      expect(own.lastScan!.rejection, CacRejection.cancelled);
    });
  });

  group('the attempt count', () {
    late InspectionHarness harness;
    late InspectionViewModel viewModel;

    setUp(() {
      clearSnackBars();
      harness = InspectionHarness();
      viewModel = harness.viewModel;
    });

    test('counts misses in a row', () async {
      harness.cacScanner.willFail(CacRejection.noCodeFound);

      await viewModel.scanCac();
      expect(viewModel.scanAttempts, 1);
      await viewModel.scanCac();
      expect(viewModel.scanAttempts, 2);
      await viewModel.scanCac();
      expect(viewModel.scanAttempts, 3);
    });

    test('a verified read zeroes it', () async {
      // The escalating advice counts misses on *this* card in *this* light. A
      // Soldier who finally got the card in frame must not be lectured about
      // glare on the next vehicle's scan.
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await viewModel.scanCac();
      await viewModel.scanCac();

      harness.cacScanner.willRead(cacBarcode());
      await viewModel.scanCac();

      expect(viewModel.scanAttempts, 0);
    });

    test('a rejection leaves it standing', () async {
      harness.cacScanner.willFail(CacRejection.cardTooSmall);
      await viewModel.scanCac();
      harness.cacScanner.willFail(CacRejection.codeUnreadable);
      await viewModel.scanCac();

      expect(viewModel.scanAttempts, 2);
    });

    test('a camera that never came back does not count as a miss', () async {
      // The counter decides two things that must only ever answer to frames
      // the decoder actually looked at: the escalating advice about how the
      // card was held, and which of SCAN AGAIN / SUBMIT UNVERIFIED leads the
      // refused card. A timeout means no frame was judged, so counting it
      // would lecture the Soldier about glare on a photograph that does not
      // exist.
      harness.cacScanner.willFail(CacRejection.cameraTimedOut);

      await viewModel.scanCac();

      expect(viewModel.lastScan!.rejection, CacRejection.cameraTimedOut);
      expect(viewModel.scanAttempts, 0);
    });

    test('backing out of the chooser does not count as a miss either',
        () async {
      final scanner = HangingCacScanner();
      final own = InspectionHarness(scanner: scanner).viewModel;
      await own.load();

      // Four fumbled choosers, no photograph taken in any of them. Counting
      // these walked the operator to 'lay the card flat and shade it' and then
      // swapped the primary action to SUBMIT UNVERIFIED — steering them to an
      // unsigned 5988-E because the camera was awkward, not because the card
      // would not read.
      for (var i = 0; i < 4; i++) {
        unawaited(own.scanCac());
        await Future<void>.delayed(Duration.zero);
        own.cancelScan();
      }

      expect(own.scanAttempts, 0);
      expect(own.lastScan!.rejection, CacRejection.cancelled);
    });

    test('a cancel rolls back only its own attempt', () async {
      final scanner = HangingCacScanner();
      final own = InspectionHarness(scanner: scanner).viewModel;
      await own.load();

      // A genuine miss first — the decoder judged a frame and it did not read.
      own.lastScan = const CacScan.rejected(CacRejection.noCodeFound);
      own.scanAttempts = 1;

      unawaited(own.scanCac());
      await Future<void>.delayed(Duration.zero);
      own.cancelScan();

      expect(own.scanAttempts, 1,
          reason: 'the miss the decoder actually judged still stands');
    });
  });

  group('walking away from the summary', () {
    late InspectionHarness harness;
    late InspectionViewModel viewModel;

    setUp(() {
      clearSnackBars();
      harness = InspectionHarness();
      viewModel = harness.viewModel;
    });

    test('backToPhases clears every scan-shaped field together', () async {
      await harness.walkToSummary();
      harness.cacScanner.willFail(CacRejection.noCodeFound);
      await viewModel.scanCac();
      await viewModel.scanCac();
      expect(viewModel.scanAttempts, 2);

      viewModel.backToPhases();

      expect(viewModel.lastScan, isNull);
      expect(viewModel.isScanning, isFalse);
      expect(viewModel.scanAttempts, 0);
      expect(viewModel.stage, InspectionStage.phaseSelect);
    });

    test(
        'resetToSetup clears them too, so one vehicle does not bleed into '
        'the next', () async {
      await harness.walkToSummary();
      harness.cacScanner.willFail(CacRejection.cameraTimedOut);
      await viewModel.scanCac();
      await viewModel.scanCac();
      await viewModel.scanCac();

      await viewModel.resetToSetup();

      expect(viewModel.lastScan, isNull);
      expect(viewModel.isScanning, isFalse);
      expect(viewModel.scanAttempts, 0);
      expect(viewModel.stage, InspectionStage.setup);
    });

    test('backing out of a scan still in flight unlatches the panel', () async {
      // backToPhases is the other way out of the scanning card, and it left
      // isScanning set. The next SCAN CAC then returned at the guard with no
      // message, for the rest of the session.
      final scanner = HangingCacScanner();
      final own = InspectionHarness(scanner: scanner).viewModel;
      await own.load();
      unawaited(own.scanCac());
      await Future<void>.delayed(Duration.zero);
      expect(own.isScanning, isTrue);

      own.backToPhases();

      expect(own.isScanning, isFalse);
      expect(own.scanAttempts, 0);

      unawaited(own.scanCac());
      await Future<void>.delayed(Duration.zero);
      expect(own.isScanning, isTrue, reason: 'the retry was swallowed');
      expect(scanner.captureCalls, 2);
    });

    test(
        'a capture landing after backToPhases does not drag the operator '
        'back', () async {
      final scanner = HangingCacScanner();
      final own = InspectionHarness(scanner: scanner).viewModel;
      await own.load();
      await own.beginSession(bumperNumber: 'A-11', uic: 'WJ8TAA');
      for (final phase in PmcsPhase.values) {
        await own.openPhase(phase);
        for (final item in own.phaseItems) {
          await own.answer(item, 0);
        }
        await own.completeActivePhase();
      }
      unawaited(own.scanCac());
      await Future<void>.delayed(Duration.zero);

      own.backToPhases();
      scanner.pending.complete(CacCapture.read(cacBarcode()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(own.stage, InspectionStage.phaseSelect);
      expect(own.lastScan, isNull);
      expect(own.isSignedOff, isFalse);
    });
  });
}

/// A port that fails the one call the view model deliberately does not await.
class ThrowingCancelScanner extends HangingCacScanner {
  @override
  Future<void> cancel() async => throw StateError('camera bridge is gone');
}
