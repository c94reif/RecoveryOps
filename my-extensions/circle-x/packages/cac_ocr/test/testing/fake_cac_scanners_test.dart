import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_core.dart';
import 'package:cac_ocr/testing.dart';

void main() {
  test('the fake answers with whatever it was told and counts the asking',
      () async {
    final scanner = FakeCacScanner()..available = false;

    expect(await scanner.isAvailable(), isFalse);
    expect((await scanner.capture()).rejection, CacRejection.noCodeFound);
    scanner.willReadFields('1087987498');
    expect((await scanner.capture()).asFields.dodId, '1087987498');
    await scanner.cancel();

    expect(scanner.captureCalls, 2);
    expect(scanner.cancelCalls, 1);
  });

  test('the hanging scanner waits for the test, even through a cancel',
      () async {
    final scanner = HangingCacScanner();
    var settled = false;

    expect(await scanner.isAvailable(), isTrue);
    final capture = scanner.capture().then((_) => settled = true);
    await scanner.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);

    scanner.pending.complete(const CacCapture.failed(CacRejection.cancelled));
    await capture;
    expect(scanner.cancelCalls, 1);
  });
}
