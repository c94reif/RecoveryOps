import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/parse_cac_barcode.dart';
import 'package:cac_ocr/src/application/verify_operator_identity.dart';

import 'package:cac_ocr/testing.dart';

void main() {
  late FakeCacScanner scanner;
  late VerifyOperatorIdentity verify;

  setUp(() {
    scanner = FakeCacScanner();
    verify = VerifyOperatorIdentity(
      scanner: scanner,
      parseBarcode: ParseCacBarcode(() => DateTime.utc(2026, 3, 24, 9)),
    );
  });

  test('a read card comes back as the Soldier holding it', () async {
    scanner.willReadBarcode(cacBarcode());

    final scan = await verify();

    expect(scan.isVerified, isTrue);
    expect(scan.identity!.displayName, 'SGT SMITH, JOHN A');
  });

  test('the camera failing is reported as the camera failing', () async {
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

  test('a readable barcode is judged by the parser, not the scanner', () async {
    scanner.willReadBarcode('1TPBOMMS10DINPAEDL');

    final scan = await verify();
    expect(scan.isVerified, isTrue);
    expect(scan.identity!.dodId, '1087987498');
  });

  test('a DoD ID the scanner read itself is judged by the number parser',
      () async {
    scanner.willReadFields('1087987498');

    final scan = await verify();
    expect(scan.isVerified, isTrue);
    expect(scan.identity!.dodId, '1087987498');
    expect(scan.identity!.displayName, 'DoD ID 1087987498');
  });

  test('ten digits outside the DEERS range are a misread, not a Soldier',
      () async {
    scanner.willReadFields('0000000001');

    expect((await verify()).rejection, CacRejection.notACac);
  });

  test('front OCR name and back OCR number reach the same identity', () async {
    scanner.result = const CacCapture.fields('1087987498',
        name: (firstName: 'JOHN MICHAEL', lastName: 'SMITH'));

    final identity = (await verify()).identity!;
    expect(identity.displayName, 'SMITH, JOHN MICHAEL');
    expect(identity.dodId, '1087987498');
    expect(identity.verifiedAt, DateTime.utc(2026, 3, 24, 9));
  });

  test('a front name cannot make an invalid back number pass', () async {
    scanner.result = const CacCapture.fields('0000000001',
        name: (firstName: 'JOHN', lastName: 'SMITH'));
    final scan = await verify();
    expect(scan.identity, isNull);
    expect(scan.rejection, CacRejection.notACac);
  });

  test('the scanner is asked exactly once per attempt', () async {
    scanner.willReadBarcode(cacBarcode());

    await verify();

    expect(scanner.captureCalls, 1);
  });

  test('a short or long OCR number cannot verify even with a front name',
      () async {
    for (final number in ['108798749', '10879874981']) {
      scanner.result = CacCapture.fields(number,
          name: (firstName: 'JOHN', lastName: 'SMITH'));
      final scan = await verify();
      expect(scan.identity, isNull);
      expect(scan.rejection, CacRejection.notACac);
    }
  });

  group('the expiry date', () {
    const read = CacFieldsCapture('1087987498',
        name: (firstName: 'JOHN A', lastName: 'SMITH'), rank: 'SGT');

    test('rank and expiry from the front reach the identity', () async {
      scanner.result = CacCapture.fields('1087987498',
          name: read.name, rank: 'SGT', expiresOn: DateTime.utc(2028, 9, 30));

      final identity = (await verify()).identity!;

      expect(identity.displayName, 'SGT SMITH, JOHN A');
      expect(identity.cardExpiresOn, DateTime.utc(2028, 9, 30));
    });

    test('a card past its date is refused by default', () async {
      scanner.result = CacCapture.fields('1087987498',
          name: read.name, expiresOn: DateTime.utc(2025, 9, 30));

      final scan = await verify();

      expect(scan.rejection, CacRejection.expired);
      expect(scan.expiredCard!.dodId, '1087987498');
    });

    test('an app that allows expired cards gets them back verified', () async {
      final lenient = VerifyOperatorIdentity(
        scanner: scanner,
        parseBarcode: ParseCacBarcode(() => DateTime.utc(2026, 3, 24, 9)),
        allowExpired: true,
      );
      scanner.result = CacCapture.fields('1087987498',
          name: read.name, expiresOn: DateTime.utc(2025, 9, 30));
      final ocr = await lenient();
      scanner.willReadBarcode(cacBarcode(expires: 'BBQH'));
      final barcode = await lenient();

      for (final scan in [ocr, barcode]) {
        expect(scan.isVerified, isTrue);
        expect(scan.identity!.isCardExpired, isTrue,
            reason: 'still dated, so the verified card can say it expired');
      }
    });
  });
}
