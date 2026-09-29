import 'package:ivy_pulse/domain/entities/cac_name.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/usecases/identity/find_cac_name.dart';
import 'package:ivy_pulse/domain/usecases/identity/find_dod_id.dart';

/// One capture attempt. Partial names never survive cancellation or a retry.
class CacOcrSession {
  static const framesToAgree = 2;
  CacScanSide _side = CacScanSide.front;
  CacName? _name;
  Object? _candidate;
  int _agreed = 0;
  String guidance = 'Fill the box with the FRONT — the side with your photo';

  CacScanSide get side => _side;
  CacRejection get timeoutRejection => side == CacScanSide.front
      ? CacRejection.nameNotFound
      : CacRejection.noCodeFound;

  CacCapture? process(List<String> lines) {
    if (side == CacScanSide.front) {
      final found = findCacName(lines);
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
    final found = findCacName(lines) == null ? findDodId(lines) : null;
    if (_agrees(found)) {
      guidance = 'Read';
      return CacCapture.read(found!, name: _name);
    }
    guidance = found == null
        ? _flipGuidance
        : 'Reading the DoD ID number — hold still';
    return null;
  }

  String get _flipGuidance =>
      'Name read: ${_name!.lastName}, ${_name!.firstName}. '
      'Flip to the BACK — hold the DoD ID number above the wide strip steady';

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
