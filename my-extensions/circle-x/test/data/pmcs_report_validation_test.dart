import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/entities/attested_identity.dart';
import 'package:circle_x/domain/entities/cac_identity.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_signature.dart';

import '../support/fakes.dart';

void main() {
  const codec = PmcsReportCodec();
  Map<String, Object?> body() => codec.reportBody(
        buildReport(signature: buildSignature(), faults: [buildFault()]),
      );

  void rejected(Map<String, Object?> report) {
    expect(codec.reportFromBody(report, fromCallsign: 'store'), isNull);
    expect(
        codec.decodeReport(jsonEncode(report), fromCallsign: 'peer'), isNull);
  }

  for (final key in ['severity', 'phase']) {
    for (final value in ['UNKNOWN', '', null]) {
      test('invalid fault $key=$value cannot become a serviceable report', () {
        final report = body();
        final fault = (report['faults'] as List).single as Map<String, Object?>;
        fault[key] = value;
        expect(
            () => PmcsFault.fromMap('session-1', fault), throwsFormatException);
        rejected(report);
      });
    }
  }

  test('RED-X spelling is rejected instead of becoming DASH', () {
    final report = body();
    ((report['faults'] as List).single as Map)['severity'] = 'RED-X';
    rejected(report);
  });

  for (final phases in [
    ['BEFORE', 'UNKNOWN'],
    ['BEFORE', 'BEFORE'],
    [1],
    'BEFORE',
  ]) {
    test('invalid phase list $phases is not silently shortened', () {
      rejected(body()..['phases'] = phases);
    });
  }

  for (final faults in [
    'bad',
    [null],
    [42],
    <String, Object?>{}
  ]) {
    test('malformed faults $faults cannot become a clean PMCS', () {
      rejected(body()..['faults'] = faults);
    });
  }

  for (final uic in ['', '   ', 'W12', 'W12ABCD', 'W12!BC']) {
    test('invalid UIC "$uic" is rejected at both receive boundaries', () {
      rejected(body()..['uic'] = uic);
    });
  }

  test('valid legacy unit still decodes and re-encodes as canonical UIC', () {
    final report = body()..remove('uic');
    report['unit'] = ' wj8taa ';
    final restored = codec.reportFromBody(report, fromCallsign: 'old client')!;
    expect(restored.uic, 'WJ8TAA');
    expect(codec.reportBody(restored)['uic'], 'WJ8TAA');
    expect(codec.reportBody(restored).containsKey('unit'), isFalse);
  });

  test('invalid UIC cannot be hidden behind a valid legacy unit', () {
    rejected(body()
      ..['uic'] = 'BAD'
      ..['unit'] = 'WJ8TAA');
  });

  for (final edipi in [
    '',
    '123',
    'abcdefghij',
    '0123456789',
    '12345678901',
    1234567890
  ]) {
    test('invalid identity number $edipi cannot verify a signature', () {
      final identity = buildIdentity().toMap()..['edipi'] = edipi;
      expect(CacIdentity.fromMap(identity), isNull);
      final signature = buildSignature().toMap()..['identity'] = identity;
      expect(PmcsSignature.fromMap(signature)?.isVerified, isFalse);
      expect(
          AttestedIdentity.fromMap({
            'edipi': edipi,
            'firstName': 'TEST',
            'lastName': 'USER',
          }),
          isNull);
    });
  }

  for (final key in ['firstName', 'lastName', 'verifiedAt']) {
    test('an incomplete identity missing $key is not verified', () {
      expect(CacIdentity.fromMap(buildIdentity().toMap()..remove(key)), isNull);
    });
  }

  test('invalid identity date and optional field types are refused', () {
    for (final entry in {
      'verifiedAt': 'not a date',
      'cardExpiresOn': 'not a date',
      'rank': 42,
    }.entries) {
      expect(
          CacIdentity.fromMap(
              buildIdentity().toMap()..[entry.key] = entry.value),
          isNull);
    }
  });

  test('a false verified flag is never promoted by an identity block', () {
    final signature = buildSignature().toMap()..['verified'] = false;
    expect(PmcsSignature.fromMap(signature)?.isVerified, isFalse);
  });
}
