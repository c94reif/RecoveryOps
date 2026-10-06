import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';
import 'package:cac_ocr/src/domain/reading/cac_ocr_session.dart';
import 'package:cac_ocr/testing.dart';

void main() {
  const front = ['NAME', 'SMITH, JOHN A', 'RANK', 'SGT'];
  const back = ['DoD ID Number 1087987498'];
  const agree = CacOcrSession.framesToAgree;
  const window = CacOcrSession.voteWindow;
  const strip = (format: CacBarcodeFormat.code39, value: '1TPBOMMS10DINPAEDL');
  const otherStrip = (
    format: CacBarcodeFormat.code39,
    value: '1TPBOMMS10DINPBEDL',
  );

  /// Feeds [lines] one frame short of agreement; nothing may come back.
  void nearly(CacOcrSession session, List<String> lines,
      {List<CacBarcode> barcodes = const []}) {
    for (var frame = 1; frame < agree; frame++) {
      expect(session.process(lines, barcodes: barcodes), isNull,
          reason: 'frame $frame of $agree');
    }
  }

  /// Feeds [lines] for a full agreement and returns what it settles on.
  CacCapture? settle(CacOcrSession session, List<String> lines,
      {List<CacBarcode> barcodes = const []}) {
    nearly(session, lines, barcodes: barcodes);
    return session.process(lines, barcodes: barcodes);
  }

  void readFront(CacOcrSession session, [List<String> lines = front]) {
    expect(settle(session, lines), isNull, reason: 'the front only flips');
    expect(session.side, CacScanSide.back);
  }

  test('requires the front before reading a DoD ID', () {
    final session = CacOcrSession();
    expect(settle(session, back), isNull);
    expect(session.side, CacScanSide.front);
    expect(session.guidance.message, contains('FRONT'));
  });

  test('reads both sides in order and retains the front name', () {
    final session = CacOcrSession();
    nearly(session, front);
    expect(session.side, CacScanSide.front);
    session.process(front);
    expect(session.side, CacScanSide.back);
    expect(session.guidance.message, contains('SMITH, JOHN A'));
    expect(session.guidance.message, contains('Flip to the BACK'));
    final capture = settle(session, back)!;
    expect(capture.asFields.dodId, '1087987498');
    expect(capture.asFields.name, (firstName: 'JOHN A', lastName: 'SMITH'));
    expect(capture.rejection, isNull);
  });

  test('a frame that reads no name neither counts nor restarts the count', () {
    final session = CacOcrSession();
    for (var frame = 1; frame < agree; frame++) {
      session.process(front);
      session.process([]);
    }
    expect(session.side, CacScanSide.front);
    session.process(front);
    expect(session.side, CacScanSide.back,
        reason: '$agree of the last $window frames read the same name');
  });

  test('a different name holds the reading until it leaves the window', () {
    final session = CacOcrSession();
    nearly(session, front);
    session.process(['NAME JONES, MARY']);
    for (var frame = 1; frame < window; frame++) {
      session.process(front);
      expect(session.side, CacScanSide.front,
          reason: 'JONES is still among the last $window frames');
    }
    session.process(front);
    expect(session.side, CacScanSide.back);
    expect(session.guidance.message, contains('SMITH, JOHN A'));
  });

  test('counts the agreeing frames for the operator', () {
    final session = CacOcrSession();
    session.process(front);
    expect(
        session.guidance,
        const CacReadingProgress(CacScanSide.front,
            agreeing: 1, needed: agree));
    expect(session.guidance.message,
        'Reading your name — hold still · 1 of $agree');
    session.process([]);
    session.process(front);
    expect(
        session.guidance,
        const CacReadingProgress(CacScanSide.front,
            agreeing: 2, needed: agree));
    session.process(['NAME JONES, MARY']);
    expect(session.guidance.message, 'Reading your name — hold still',
        reason: 'two names in the window are no progress');
    expect(session.contested, isTrue);
    expect(session.backing, 1);

    final back = CacOcrSession(sides: CacSides.backOnly);
    back.process(const ['DoD ID Number 1087987498']);
    expect(back.guidance.message,
        'Reading the 10-digit DoD ID number — hold still · 1 of $agree');
  });

  test('a reset puts back the prompt for the side, not stale progress', () {
    final session = CacOcrSession();
    final opening = session.guidance;
    session.process(front);
    session.resetFrameAgreement();
    expect(session.guidance, opening);

    readFront(session);
    final flip = session.guidance;
    session.process(back);
    expect(session.guidance.message, contains('1 of $agree'));
    session.resetFrameAgreement();
    expect(session.guidance, flip);

    final backOnly = CacOcrSession(sides: CacSides.backOnly);
    final backOpening = backOnly.guidance;
    backOnly.process(back);
    backOnly.resetFrameAgreement();
    expect(backOnly.guidance, backOpening);
  });

  test('tells the viewfinder what the frame found', () {
    final session = CacOcrSession();
    session.process(front);
    expect(session.sawCard, isTrue);
    expect(session.lastNameRead, (firstName: 'JOHN A', lastName: 'SMITH'));
    expect(session.lastDodIdRead, isNull);
    session.process([]);
    expect(session.sawCard, isFalse);
    expect(session.lastNameRead, isNull);

    readFront(session);
    session.process(back);
    expect(session.sawCard, isTrue);
    expect(session.lastDodIdRead, '1087987498');
    expect(session.lastNameRead, isNull);
    session.process(front);
    expect(session.sawCard, isFalse,
        reason: 'the front is not what the back is read for');
    expect(session.lastDodIdRead, isNull);
    session.process(const ['DoD ID Number 108798749']);
    expect(session.sawCard, isFalse);
  });

  test('the front cannot supply a number before the card is flipped', () {
    final session = CacOcrSession();
    final frontWithNumber = [...front, ...back];
    readFront(session, frontWithNumber);
    expect(settle(session, frontWithNumber), isNull);
    expect(session.guidance.message, contains('Flip to the BACK'));
    expect(settle(session, back)!.asFields.dodId, '1087987498');
  });

  test('a frame with no valid number neither counts nor restarts the count',
      () {
    for (final unreadable in [
      <String>[],
      ['DoD ID Number 0000000001'],
      ['DoD ID Number 108798749'],
      ['DoD ID Number 10879874981'],
      ['DoD ID Number 1087987498-1'],
      ['DoD Benefits Number 1087987498'],
      ['DoD Benefits Number 10879874981'],
    ]) {
      final session = CacOcrSession();
      readFront(session);
      for (var frame = 1; frame < agree; frame++) {
        expect(session.process(back), isNull);
        expect(session.process(unreadable), isNull, reason: '$unreadable');
      }
      expect(session.process(back)?.asFields.name?.lastName, 'SMITH',
          reason: '$unreadable');
    }
  });

  test('a different number holds the reading until it leaves the window', () {
    final session = CacOcrSession();
    readFront(session);
    nearly(session, back);
    expect(session.process(['DoD ID Number 1098765432']), isNull);
    for (var frame = 1; frame < window; frame++) {
      expect(session.process(back), isNull,
          reason: 'the other number is still among the last $window frames');
    }
    expect(session.process(back)!.asFields.dodId, '1087987498');
  });

  test('short and long reads explain the length and keep scanning', () {
    final session = CacOcrSession();
    readFront(session);

    for (var frame = 0; frame < agree + 2; frame++) {
      expect(session.process(['DoD ID Number 108798749']), isNull);
      expect(session.guidance.message, contains('Read 9 of 10 digits'));
      expect(session.guidance.message, contains('Rescan the back of your CAC'));
      expect(session.side, CacScanSide.back);
    }
    expect(session.process(['DoD ID Number 10879874981']), isNull);
    expect(session.guidance.message, contains('Read 11 digits'));
    expect(session.guidance.message, contains('exactly 10'));
    expect(session.guidance.message, contains('Rescan the back of your CAC'));
    expect(settle(session, back)!.asFields.dodId, '1087987498');
  });

  test('a timeout tells the operator which side could not be read', () {
    final session = CacOcrSession();
    expect(session.timeoutRejection, CacRejection.nameNotFound);
    readFront(session);
    expect(session.timeoutRejection, CacRejection.noCodeFound);
  });

  test('a new attempt cannot reuse a partial name from the previous scan', () {
    final abandoned = CacOcrSession();
    readFront(abandoned);
    final retry = CacOcrSession();
    expect(settle(retry, back), isNull);
    readFront(retry, ['NAME JONES, MARY']);
    expect(settle(retry, back)!.asFields.name,
        (firstName: 'MARY', lastName: 'JONES'));
  });

  group('reading the back alone', () {
    test('starts on the back and asks for the DoD ID, not a name', () {
      final session = CacOcrSession(sides: CacSides.backOnly);

      expect(session.side, CacScanSide.back);
      expect(session.guidance.message, contains('BACK'));
      expect(session.guidance.message, isNot(contains('FRONT')));
      expect(session.timeoutRejection, CacRejection.noCodeFound);
    });

    test('agreeing frames give the number with no name beside it', () {
      final session = CacOcrSession(sides: CacSides.backOnly);

      final capture = settle(session, back)!;
      expect(capture.asFields.dodId, '1087987498');
      expect(capture.asFields.name, isNull);
      expect(session.side, CacScanSide.back, reason: 'there is no flip');
    });

    test('a front held up is turned over, never read for a number', () {
      final session = CacOcrSession(sides: CacSides.backOnly);
      final frontWithNumber = [...front, ...back];

      expect(settle(session, frontWithNumber), isNull);
      expect(session.guidance.message, contains('Turn it over'));
      expect(session.guidance.message, isNot(contains('Name read')));
      expect(settle(session, back)!.asFields.dodId, '1087987498');
    });

    test('a short read still says how many digits it saw', () {
      final session = CacOcrSession(sides: CacSides.backOnly);

      session.process(['DoD ID Number 108798749']);

      expect(session.guidance.message, contains('Read 9 of 10 digits'));
      expect(session.unreadableFrames, 1);
    });
  });

  group('the rest of the front', () {
    const printed = [
      'Name',
      'SMITH, JOHN A',
      'Rank',
      'SGT',
      'Expires',
      '2029 SEP 30',
    ];

    test('the rank and expiry ride along with the name and the number', () {
      final session = CacOcrSession();
      readFront(session, printed);
      expect(
          session.guidance.message, contains('Name read: SGT SMITH, JOHN A.'));
      final capture = settle(session, back)!;

      expect(capture.asFields.rank, 'SGT');
      expect(capture.asFields.expiresOn, DateTime.utc(2029, 9, 30));
      expect(capture.asFields.name, (firstName: 'JOHN A', lastName: 'SMITH'));
    });

    test('a rank or date seen on one frame only does not slip through', () {
      final session = CacOcrSession();
      session.process(printed);
      for (var frame = 1; frame < window; frame++) {
        session.process(front);
        expect(session.side, CacScanSide.front,
            reason: 'a missed expiry is a different reading of the card');
      }
      session.process(front);
      expect(session.side, CacScanSide.back);

      expect(settle(session, back)!.asFields.expiresOn, isNull);
    });

    test('a front without rank or expiry still reads', () {
      final session = CacOcrSession();
      readFront(session, ['NAME', 'SMITH, JOHN A']);
      final capture = settle(session, back)!;

      expect(capture.asFields.rank, isEmpty);
      expect(capture.asFields.expiresOn, isNull);
    });

    test('an expiry no card issued on that date could carry is dropped', () {
      CacCapture readWithIssue(String issued, String expires) {
        final session = CacOcrSession();
        readFront(session, [...front, 'Issued $issued', 'Expires $expires']);
        return settle(session, back)!;
      }

      expect(readWithIssue('2026 SEP 30', '2024 SEP 30').asFields.expiresOn,
          isNull,
          reason: 'it cannot expire before it was issued');
      expect(readWithIssue('2023 SEP 30', '2029 SEP 30').asFields.expiresOn,
          isNull,
          reason: 'no CAC is issued for six years');
      expect(readWithIssue('2026 SEP 30', '2029 SEP 30').asFields.expiresOn,
          DateTime.utc(2029, 9, 30));
    });
  });

  group('barcodes', () {
    test("a CAC's front PDF417 is the whole read, with no flip", () {
      final session = CacOcrSession();
      final record = (format: CacBarcodeFormat.pdf417, value: cacBarcode());

      final capture = session.process([], barcodes: [record])!;

      expect(capture.asBarcode.raw, cacBarcode());
      expect(session.guidance, CacInstruction.cardRead);
    });

    test('a PDF417 that is not a CAC record is ignored', () {
      final session = CacOcrSession();
      const licence = (
        format: CacBarcodeFormat.pdf417,
        value: 'ANSI 636000080002DL',
      );

      expect(session.process(front, barcodes: [licence]), isNull);
      expect(session.side, CacScanSide.front);
    });

    test('the back strip agreeing with the print settles it in one frame', () {
      final session = CacOcrSession();
      readFront(session);

      final capture = session.process(back, barcodes: [strip])!;

      expect(capture.asFields.dodId, '1087987498');
      expect(capture.asFields.name!.lastName, 'SMITH');
    });

    test('a strip that disagrees with the print throws the frame away', () {
      final session = CacOcrSession();
      readFront(session);

      for (var frame = 0; frame <= agree; frame++) {
        expect(session.process(back, barcodes: [otherStrip]), isNull);
      }
      expect(session.guidance.message, contains('disagree'));
      expect(settle(session, back)!.asFields.dodId, '1087987498');
    });

    test('the strip alone still has to read the same on every frame', () {
      final session = CacOcrSession();
      readFront(session);

      final capture = settle(session, [], barcodes: [strip])!;

      expect(capture.asFields.dodId, '1087987498');
      expect(capture.asFields.name!.lastName, 'SMITH');
    });

    test('the strip vouches for the back while front text is in view', () {
      final session = CacOcrSession();
      readFront(session);

      final capture = session.process([...front, ...back], barcodes: [strip]);

      expect(capture!.asFields.dodId, '1087987498');
    });

    test('the strip shown first asks for the front', () {
      final session = CacOcrSession();

      expect(settle(session, front, barcodes: [strip]), isNull);
      expect(session.side, CacScanSide.front);
      expect(session.guidance.message, contains('That is the back'));
    });

    test('reading the back alone, a front PDF417 means turn the card over', () {
      final session = CacOcrSession(sides: CacSides.backOnly);
      final record = (format: CacBarcodeFormat.pdf417, value: cacBarcode());

      expect(session.process([], barcodes: [record]), isNull);
      expect(session.guidance.message, contains('Turn it over'));
    });
  });
}
