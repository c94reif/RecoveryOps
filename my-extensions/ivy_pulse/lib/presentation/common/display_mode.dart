import 'package:flutter/foundation.dart';

/// Quarter turns applied to the whole extension UI — a testing lever, not a
/// shipping feature.
///
/// Host 0.9.0 gives a web extension no way to rotate the device: the activity
/// is `userLandscape`, the registration manifest carries no orientation field,
/// and `LatticeEdgeExtension.preferredOrientation` is only read for extensions
/// compiled natively into the host. Rotating our own content is the only
/// portrait we can reach from inside the WebView — the operator turns the
/// device to match, and the host's header and tab bar stay landscape.
///
/// 0 = off, 1 = clockwise, 3 = counter-clockwise. Both directions are here
/// because which one reads upright depends on which way the device is turned.
///
/// [defaultQuarterTurns] is what the extension opens in: a walk-around is done
/// on a device held upright, so portrait is the resting state and landscape is
/// the exception. Counter-clockwise is the one that reads upright on the
/// device this was built against.
const int defaultQuarterTurns = 3;

final ValueNotifier<int> verticalQuarterTurns =
    ValueNotifier<int>(defaultQuarterTurns);

/// Whether the extension currently owns the whole device screen, kept in step
/// with the document so the system back gesture can't leave the label lying.
final ValueNotifier<bool> fullScreenOn = ValueNotifier<bool>(false);
