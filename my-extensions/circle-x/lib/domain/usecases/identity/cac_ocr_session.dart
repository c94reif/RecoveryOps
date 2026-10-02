import 'package:circle_x/domain/entities/cac_name.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/usecases/identity/find_cac_name.dart';
import 'package:circle_x/domain/usecases/identity/find_dod_id.dart';

/// One capture attempt. Partial names never survive cancellation or a retry.
class CacOcrSession {
  static const framesToAgree = 2;
  CacScanSide _side = CacScanSide.front;
  CacName? _name;
  Object? _candidate;
  int _agreed = 0;
  int unreadableFrames = 0;
  String guidance = 'Fill the box with the FRONT — the side with your photo';

  CacScanSide get side => _side;
  CacRejection get timeoutRejection => side == CacScanSide.front
      ? CacRejection.nameNotFound
      : CacRejection.noCodeFound;

  CacCapture? process(List<String> lines) {
    if (side == CacScanSide.front) {
      final found = findCacName(lines);
      unreadableFrames = found == null ? unreadableFrames + 1 : 0;
      if (_agrees(found)) {
        _name = found;
        _side = CacScanSide.back;
        _candidate = null;
        _agreed = 0;
        guidance = _flipGuidance;
      } else {
        guidance = found != null
            ? 'Reading your name — hold still'
            : 'Show the FRONT — hold the printed name below your photo steady';
      }
      return null;
    }

    // A still-visible front must not supply an unrelated ten-digit number.
    if (findCacName(lines) != null) {
      unreadableFrames = 0;
      _agrees(null);
      guidance = _flipGuidance;
      return null;
    }
    final reading = inspectDodId(lines);
    final found = reading.dodId;
    unreadableFrames = found == null ? unreadableFrames + 1 : 0;
    if (_agrees(found)) {
      guidance = 'Read';
      return CacCapture.read(found!, name: _name);
    }
    final digitCount = reading.digitCount;
    guidance = switch (digitCount) {
      int count when count < 10 =>
        'Read $count of 10 digits. Rescan the back of your CAC — '
            'hold the full DoD ID number steady in the box.',
      int count when count > 10 =>
        'Read $count digits; DoD ID must be exactly 10. '
            'Rescan the back of your CAC — show the DoD ID number '
            'above the wide strip.',
      _ => found == null
          ? 'Rescan the back of your CAC — hold the full 10-digit DoD ID '
              'number clear and steady above the wide strip.'
          : 'Reading the 10-digit DoD ID number — hold still',
    };
    return null;
  }

  String get _flipGuidance =>
      'Name read: ${_name!.lastName}, ${_name!.firstName}. '
      'Flip to the BACK — hold the DoD ID number above the wide strip steady';

  /// Focus, resolution or orientation changes start fresh frame agreement.
  void resetFrameAgreement() {
    _candidate = null;
    _agreed = 0;
    unreadableFrames = 0;
  }

  bool _agrees(Object? found) {
    if (found == null) {
      _candidate = null;
      _agreed = 0;
      return false;
    }
    _agreed = found == _candidate ? _agreed + 1 : 1;
    _candidate = found;
    return _agreed >= framesToAgree;
  }
}
