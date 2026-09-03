import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/domain/entities/recoveryRequest.dart';
import 'package:recovery_ops/data/services/regexTranscriptParsetr.dart';

void main() {
  late RegexTranscriptParser parser;

  setUp(() {
    parser = RegexTranscriptParser();
  });


  test('parses simple bumper and issue', () async {
    final result = await parser.parse('HQ-42 flat tire');

    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, isNull);
  });

  test('parses single word as bumper only', () async {
    final result = await parser.parse('HQ-42');

    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, '');
  });

  test('handles empty string', () async {
    final result = await parser.parse('');

    expect(result.bumperNumber, '');
    expect(result.issue, '');
    expect(result.recoveryType, isNull);
  });

  test('handles whitespace-only string', () async {
    final result = await parser.parse('   ');

    expect(result.bumperNumber, '');
    expect(result.issue, '');
  });


  test('extracts bumper with hyphen', () async {
    final result = await parser.parse('HQ-42 engine failure');
    expect(result.bumperNumber, 'HQ-42');
  });

  test('extracts bumper without hyphen', () async {
    final result = await parser.parse('HQ23 engine failure');
    expect(result.bumperNumber, 'HQ23');
  });

  test('extracts bumper with space spoken as dash', () async {
    final result = await parser.parse('Bumper number HQ 23 has a flat tire');
    expect(result.bumperNumber, 'HQ-23');
  });

  test('returns empty bumper when no pattern matches', () async {
    final result = await parser.parse('flat tire wrecker');
    expect(result.bumperNumber, '');
    expect(result.issue, 'flat tire');
  });


  test('detects wrecker', () async {
    final result = await parser.parse('HQ-42 flat tire wrecker');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('detects tow bar', () async {
    final result = await parser.parse('BR-07 engine failure tow bar');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('detects wrecker case-insensitive', () async {
    final result = await parser.parse('HQ-42 flat tire Wrecker');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('detects flatbed as wrecker', () async {
    final result = await parser.parse('HQ-42 engine failure need a flatbed');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('detects heavy recovery as wrecker', () async {
    final result = await parser.parse('BR-07 stuck in mud heavy recovery');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('detects towing as tow bar', () async {
    final result = await parser.parse('HQ-42 dead battery needs towing');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('detects tow strap as tow bar', () async {
    final result = await parser.parse('BR-07 flat tire tow strap');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('no type keyword leaves recoveryType null', () async {
    final result = await parser.parse('HQ-42 flat tire');
    expect(result.recoveryType, isNull);
  });


  test('natural sentence with bumper number in middle', () async {
    final result = await parser.parse(
      "Bumper number HQ-23 has a flat tire and I'm in need of a wrecker",
    );
    expect(result.bumperNumber, 'HQ-23');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('natural sentence with tow bar', () async {
    final result = await parser.parse(
      'Bumper number BR-07 has a dead battery and I need a tow bar',
    );
    expect(result.bumperNumber, 'BR-07');
    expect(result.issue, 'dead battery');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('requesting phrasing', () async {
    final result = await parser.parse(
      'Requesting a wrecker for vehicle number HQ-42 due to engine failure',
    );
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'engine failure');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('please send phrasing', () async {
    final result = await parser.parse(
      'Please send a tow bar for HQ-23 it has a flat tire',
    );
    expect(result.bumperNumber, 'HQ-23');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('we need phrasing', () async {
    final result = await parser.parse(
      'We need a wrecker for BR-07 with a dead battery',
    );
    expect(result.bumperNumber, 'BR-07');
    expect(result.issue, 'dead battery');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('normalizes blown tire to flat tire', () async {
    final result = await parser.parse('HQ-42 blown tire wrecker');
    expect(result.issue, 'flat tire');
  });

  test('normalizes overheated to overheating', () async {
    final result = await parser.parse('BR-07 overheated wrecker');
    expect(result.issue, 'overheating');
  });

  test('normalizes no start to will not start', () async {
    final result = await parser.parse('HQ-42 no start tow bar');
    expect(result.issue, 'will not start');
  });


  test('strips type keyword from middle of issue', () async {
    final result = await parser.parse('HQ-42 wrecker needs engine repair');
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'needs engine repair');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('strips it is filler', () async {
    final result = await parser.parse("HQ-42 it's a flat tire wrecker");
    expect(result.issue, 'flat tire');
  });

  test('strips vehicle id phrasing', () async {
    final result = await parser.parse('Vehicle number HQ-42 has a flat tire');
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
  });


  test('type first then bumper then issue', () async {
    final result = await parser.parse('Wrecker for HQ-42 flat tire');
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('issue first then bumper then type', () async {
    final result = await parser.parse('Flat tire on HQ-42 send a wrecker');
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('type then issue then bumper', () async {
    final result = await parser.parse('I need a tow bar dead battery on BR-07');
    expect(result.bumperNumber, 'BR-07');
    expect(result.issue, 'dead battery');
    expect(result.recoveryType, RecoveryType.towBar);
  });

  test('bumper in middle of natural sentence', () async {
    final result = await parser.parse(
      'Send a wrecker to HQ-23 because of engine failure',
    );
    expect(result.bumperNumber, 'HQ-23');
    expect(result.issue, 'engine failure');
    expect(result.recoveryType, RecoveryType.wrecker);
  });

  test('type and bumper with issue scattered', () async {
    final result = await parser.parse(
      "I need a wrecker, bumper number HQ-42, it has a flat tire",
    );
    expect(result.bumperNumber, 'HQ-42');
    expect(result.issue, 'flat tire');
    expect(result.recoveryType, RecoveryType.wrecker);
  });
}
