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
    // The Code 39 off the back of a CAC. The scanner read it perfectly well;
    // only the parser knows it is the wrong face of the right card.
    scanner.willRead('1TPBOMMS10DINPAEDL');

    expect((await verify()).rejection, CacRejection.wrongSideOfCard);
  });

  test('the scanner is asked exactly once per attempt', () async {
    scanner.willRead(cacBarcode());

    await verify();

    expect(scanner.captureCalls, 1);
  });
}
