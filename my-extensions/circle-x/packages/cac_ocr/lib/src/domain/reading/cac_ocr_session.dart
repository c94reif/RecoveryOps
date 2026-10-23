import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_capture.dart';
import 'package:cac_ocr/src/domain/cac_card_dates.dart';
import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';
import 'package:cac_ocr/src/domain/parse_cac_barcode.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';
import 'package:cac_ocr/src/domain/reading/cac_vote_window.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_expiry.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_name.dart';
import 'package:cac_ocr/src/domain/reading/find_cac_rank.dart';
import 'package:cac_ocr/src/domain/reading/find_dod_id.dart';

typedef _Front = ({CacName name, String rank, DateTime? expiresOn});

class CacOcrSession {
  static const framesToAgree = 3;
  static const voteWindow = 5;
  final CacSides sides;
  CacScanSide _side;
  _Front? _front;
  final _votes = CacVoteWindow<Object>(size: voteWindow, needed: framesToAgree);
  int _unreadableFrames = 0;
  CacGuidance _guidance;
  bool _sawCard = false;
  CacName? _lastNameRead;
  String? _lastDodIdRead;

  CacOcrSession({this.sides = CacSides.frontAndBack})
      : _side = sides.firstSide,
        _guidance = _opening(sides);

  static CacGuidance _opening(CacSides sides) => sides == CacSides.backOnly
      ? CacInstruction.showBack
      : CacInstruction.showFront;

  CacScanSide get side => _side;
  CacGuidance get guidance => _guidance;

  int get unreadableFrames => _unreadableFrames;

  bool get sawCard => _sawCard;

  CacName? get lastNameRead => _lastNameRead;
  String? get lastDodIdRead => _lastDodIdRead;

  int get backing => _votes.backing;
  bool get contested => _votes.contested;

  CacRejection get timeoutRejection => side == CacScanSide.front
      ? CacRejection.nameNotFound
      : CacRejection.noCodeFound;

  CacCapture? process(List<String> lines,
      {List<CacBarcode> barcodes = const []}) {
    final record = _frontRecord(barcodes);
    final barcodeId = _backDodId(barcodes);
    _sawCard = false;
    _lastNameRead = null;
    _lastDodIdRead = null;
    return side == CacScanSide.front
        ? _processFront(lines, record, barcodeId)
        : _processBack(lines, record, barcodeId);
  }

  CacCapture? _processFront(
      List<String> lines, String? record, String? barcodeId) {
    if (record != null) {
      _sawCard = true;
      _guidance = CacInstruction.cardRead;
      return CacCapture.barcode(record);
    }
    if (barcodeId != null) {
      _restart(CacInstruction.frontFirst);
      return null;
    }
    final found = _readFront(lines);
    _unreadableFrames = found == null ? _unreadableFrames + 1 : 0;
    _sawCard = found != null;
    _lastNameRead = found?.name;
    if (_votes.add(found)) {
      _front = found;
      _side = CacScanSide.back;
      _votes.clear();
      _guidance = _flip;
    } else {
      _guidance = found != null ? _progress : CacInstruction.findName;
    }
    return null;
  }

  CacCapture? _processBack(
      List<String> lines, String? record, String? barcodeId) {
    if (barcodeId == null && (record != null || findCacName(lines) != null)) {
      _restart(sides == CacSides.backOnly ? CacInstruction.turnOver : _flip);
      return null;
    }
    final reading = inspectDodId(lines);
    final printed = reading.dodId;
    _sawCard = barcodeId != null || printed != null;
    if (barcodeId != null && printed != null && barcodeId != printed) {
      _restart(CacInstruction.numbersDisagree);
      return null;
    }
    final found = barcodeId ?? printed;
    _unreadableFrames = found == null ? _unreadableFrames + 1 : 0;
    _lastDodIdRead = found;
    if ((barcodeId != null && barcodeId == printed) || _votes.add(found)) {
      _guidance = CacInstruction.cardRead;
      final front = _front;
      return CacCapture.fields(found!,
          name: front?.name,
          rank: front?.rank ?? '',
          expiresOn: front?.expiresOn);
    }
    _guidance = switch ((found, reading.digitCount)) {
      (String(), _) => _progress,
      (_, int count) when count != DodId.length => CacDigitCount(count),
      _ => CacInstruction.findDodId,
    };
    return null;
  }

  void _restart(CacGuidance guidance) {
    _unreadableFrames = 0;
    _votes.clear();
    _guidance = guidance;
  }

  static String? _frontRecord(List<CacBarcode> barcodes) => [
        for (final barcode in barcodes)
          if (barcode.format == CacBarcodeFormat.pdf417 &&
              ParseCacBarcode.isFrontRecord(barcode.value))
            barcode.value,
      ].firstOrNull;

  static String? _backDodId(List<CacBarcode> barcodes) => [
        for (final barcode in barcodes)
          if (barcode.format == CacBarcodeFormat.code39)
            if (ParseCacBarcode.dodIdFromCode39(barcode.value) case final id?)
              id,
      ].firstOrNull;

  CacGuidance get _flip => CacFlipCard(_front!.name, rank: _front!.rank);

  CacGuidance get _progress => CacReadingProgress(side,
      agreeing: contested ? null : backing, needed: framesToAgree);

  static _Front? _readFront(List<String> lines) {
    final name = findCacName(lines);
    if (name == null) return null;
    final expiresOn = findCacExpiry(lines);
    final issuedOn = findCacIssueDate(lines);
    return (
      name: name,
      rank: findCacRank(lines) ?? '',
      // An expiry no card issued on that date could carry is a misread.
      expiresOn: expiresOn != null &&
              issuedOn != null &&
              !CacCardDates.plausible(issuedOn, expiresOn)
          ? null
          : expiresOn,
    );
  }

  void resetFrameAgreement() {
    _votes.clear();
    _unreadableFrames = 0;
    _guidance = _front == null ? _opening(sides) : _flip;
  }
}
