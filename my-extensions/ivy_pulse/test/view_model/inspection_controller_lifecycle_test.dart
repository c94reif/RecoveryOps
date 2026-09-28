import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';
import 'package:ivy_pulse/domain/services/user_notification_sink.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';
import 'package:ivy_pulse/presentation/inspection/controllers/cac_scan_controller.dart';
import 'package:ivy_pulse/presentation/inspection/controllers/fault_dictation_controller.dart';

class PendingCacScanner implements CacScannerStrategy {
  final pending = Completer<CacCapture>();
  bool cancelled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() => pending.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

class PendingSpeechRecognition implements SpeechRecognitionStrategy {
  late void Function(String) result;
  @override
  bool isListening = false;
  bool stopped = false;

  @override
  Future<void> startListening({required void Function(String) onResult}) async {
    result = onResult;
    isListening = true;
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
    stopped = true;
  }
}

void main() {
  test('disposing a scan cancels capture and ignores its late result',
      () async {
    final scanner = PendingCacScanner();
    final controller = CacScanController(
      cacScanner: scanner,
      verifyOperatorIdentity: VerifyOperatorIdentity(
        scanner: scanner,
        parseBarcode: const ParseCacBarcode(SystemClock()),
      ),
    );
    var changes = 0;
    controller.addListener(() => changes++);
    final scanning = controller.scan();
    expect(changes, 1);
    controller.dispose();
    scanner.pending.complete(const CacCapture.failed(CacRejection.cancelled));
    await scanning;
    expect(scanner.cancelled, isTrue);
    expect(changes, 1);
    expect(controller.lastScan, isNull);
  });

  test('disposing dictation stops speech and ignores its late result',
      () async {
    final speech = PendingSpeechRecognition();
    final controller = FaultDictationController(
      speech: speech,
      notifications: const SilentNotificationSink(),
    );
    final notes = <String>[];
    await controller.toggle(
      itemId: 'B-ENG-01',
      isCurrent: () => true,
      onResult: (text) async => notes.add(text),
    );
    controller.dispose();
    speech.result('Late transcription');
    await Future<void>.delayed(Duration.zero);
    expect(speech.stopped, isTrue);
    expect(notes, isEmpty);
  });
}
