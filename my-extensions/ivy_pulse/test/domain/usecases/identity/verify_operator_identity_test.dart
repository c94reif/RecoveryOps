import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/clock.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';

import '../../../support/cac_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late FakeCacScanner scanner;
  late VerifyOperatorIdentity verify;

  setUp(() {
    scanner = FakeCacScanner();
    verify = VerifyOperatorIdentity(
      scanner: scanner,
      parseBarcode: ParseCacBarcode(FixedClock(DateTime.utc(2026, 3, 24, 9))),
    );
  });

  test('a read card comes back as the Soldier holding it', () async {
    scanner.willRead(cacBarcode());

    final scan = await verify();

    expect(scan.isVerified, isTrue);
    expect(scan.identity!.displayName, 'SGT SMITH, JOHN A');
  });

  test('the camera failing is reported as the camera failing', () async {
    // The operator needs to know whether to shoot the card again or stop
    // trying, so the capture reason survives rather than collapsing into a
    // generic failure.
    scanner.willFail(CacRejection.noCamera);

    final scan = await verify();

    expect(scan.isVerified, isFalse);
    expect(scan.rejection, CacRejection.noCamera);
  });

  test('a cancelled scan is not a failed one', () async {
    scanner.willFail(CacRejection.cancelled);

    expect((await verify()).rejection, CacRejection.cancelled);
  });

  test('a frame with no barcode in it says so', () async {
    scanner.willFail(CacRejection.noCodeFound);

    expect((await verify()).rejection, CacRejection.noCodeFound);
  });

  test('a readable barcode is judged by the parser, not the scanner',
      () async {
    // The Code 39 off the back of a CAC: the parser, not the scanner, turns
    // it into a Soldier by DoD ID.
    scanner.willRead('1TPBOMMS10DINPAEDL');

    final scan = await verify();
    expect(scan.isVerified, isTrue);
    expect(scan.identity!.edipi, '1087987498');
  });

  test('ten digits read as text is a DoD ID, judged by the number parser',
      () async {
    // What the Android scanner hands over: the printed number, OCR'd off the
    // back. No barcode record is ten characters, so shape alone routes it.
    scanner.willRead('1087987498');

    final scan = await verify();
    expect(scan.isVerified, isTrue);
    expect(scan.identity!.edipi, '1087987498');
    expect(scan.identity!.displayName, 'DoD ID 1087987498');
  });

  test('ten digits outside the DEERS range are a misread, not a Soldier',
      () async {
    scanner.willRead('0000000001');

    expect((await verify()).rejection, CacRejection.notACac);
  });

  test('the scanner is asked exactly once per attempt', () async {
    scanner.willRead(cacBarcode());

    await verify();

    expect(scanner.captureCalls, 1);
  });
}
