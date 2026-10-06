import 'dart:async';

import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';

class FakeCacScanner implements CacScannerStrategy {
  bool available = true;
  CacCapture result = const CacCapture.failed(CacRejection.noCodeFound);
  Object? throwOnCapture;
  int captureCalls = 0;
  int cancelCalls = 0;

  void willReadBarcode(String raw) => result = CacCapture.barcode(raw);

  void willReadFields(String dodId,
          {CacName? name, String rank = '', DateTime? expiresOn}) =>
      result = CacCapture.fields(dodId,
          name: name, rank: rank, expiresOn: expiresOn);

  void willFail(CacRejection rejection) =>
      result = CacCapture.failed(rejection);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CacCapture> capture() async {
    captureCalls++;
    if (throwOnCapture != null) throw throwOnCapture!;
    return result;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}

class HangingCacScanner implements CacScannerStrategy {
  final Completer<CacCapture> pending = Completer<CacCapture>();
  int captureCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CacCapture> capture() {
    captureCalls++;
    return pending.future;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}
