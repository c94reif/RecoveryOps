import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/usecases/identity/parse_dod_id.dart';

import 'package:ivy_pulse/domain/services/clock.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 3, 24, 9));
  final parse = ParseDodId(clock);

  group('a DoD ID number read off the back of the card', () {
    test('signs the PMCS by number, with no name to put beside it', () {
      final scan = parse('1087987498');

      expect(scan.isVerified, isTrue);
      expect(scan.identity!.edipi, '1087987498');
      expect(scan.identity!.firstName, isEmpty);
      expect(scan.identity!.lastName, isEmpty);
      expect(scan.identity!.rank, isEmpty);
      expect(scan.identity!.displayName, 'DoD ID 1087987498');
    });

    test('is stamped with the scan instant off the injected clock', () {
      expect(parse('1087987498').identity!.verifiedAt, clock.nowUtc());
    });

    test('tolerates the spaces and dashes OCR leaves in', () {
      expect(parse('1087 987 498').identity?.edipi, '1087987498');
      expect(parse('1087-987-498').identity?.edipi, '1087987498');
    });

    test('refuses anything that is not ten digits', () {
      expect(parse('108798749').rejection, CacRejection.notACac);
      expect(parse('10879874981').rejection, CacRejection.notACac);
      expect(parse('').rejection, CacRejection.notACac);
      expect(parse('SGT SMITH').rejection, CacRejection.notACac);
    });

    test('refuses ten digits DEERS has never issued', () {
      // A misread digit, not a Soldier who does not exist.
      expect(parse('0000000001').rejection, CacRejection.notACac);
      expect(parse('0999999999').rejection, CacRejection.notACac);
    });
  });
}
