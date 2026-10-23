import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';

sealed class CacGuidance {
  const CacGuidance();

  String get message;
}

enum CacInstruction implements CacGuidance {
  startingCamera('Starting camera…'),
  adjustingCamera('Adjusting camera for a clearer read — hold the card steady'),
  tiltFromGlare(
      'Tilt the card away from the light — glare is hiding the print'),
  showFront('Fill the box with the FRONT — the side with your photo'),
  showBack(
      'Fill the box with the BACK — the DoD ID number above the wide strip'),
  findName('Show the FRONT — hold the printed name below your photo steady'),
  frontFirst(
      'That is the back. Show the front first — the side with your photo'),
  turnOver('That is the side with your photo. Turn it over — hold the DoD ID '
      'number above the wide strip steady'),
  numbersDisagree(
      'The printed number and the barcode disagree — hold the card steady'),
  findDodId('Rescan the back of your CAC — hold the full 10-digit DoD ID '
      'number clear and steady above the wide strip.'),
  cardRead('Read');

  const CacInstruction(this.message);

  @override
  final String message;
}

final class CacReadingProgress extends CacGuidance {
  final CacScanSide side;
  final int? agreeing;
  final int needed;

  const CacReadingProgress(this.side,
      {required this.agreeing, required this.needed});

  @override
  String get message {
    final what = side == CacScanSide.front
        ? 'Reading your name'
        : 'Reading the 10-digit DoD ID number';
    final count = agreeing == null ? '' : ' · $agreeing of $needed';
    return '$what — hold still$count';
  }

  @override
  bool operator ==(Object other) =>
      other is CacReadingProgress &&
      other.side == side &&
      other.agreeing == agreeing &&
      other.needed == needed;

  @override
  int get hashCode => Object.hash(side, agreeing, needed);
}

final class CacFlipCard extends CacGuidance {
  final CacName name;
  final String rank;

  const CacFlipCard(this.name, {this.rank = ''});

  @override
  String get message {
    final title = rank.isEmpty ? '' : '$rank ';
    return 'Name read: $title${name.lastName}, ${name.firstName}. Flip to the '
        'BACK — hold the DoD ID number above the wide strip steady';
  }

  @override
  bool operator ==(Object other) =>
      other is CacFlipCard && other.name == name && other.rank == rank;

  @override
  int get hashCode => Object.hash(name, rank);
}

final class CacDigitCount extends CacGuidance {
  final int digits;

  const CacDigitCount(this.digits);

  @override
  String get message => digits < DodId.length
      ? 'Read $digits of 10 digits. Rescan the back of your CAC — hold the '
          'full DoD ID number steady in the box.'
      : 'Read $digits digits; DoD ID must be exactly 10. Rescan the back of '
          'your CAC — show the DoD ID number above the wide strip.';

  @override
  bool operator ==(Object other) =>
      other is CacDigitCount && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
