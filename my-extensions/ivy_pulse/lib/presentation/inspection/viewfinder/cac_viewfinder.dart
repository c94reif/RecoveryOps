import 'package:flutter/widgets.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

// The Android viewfinder draws the camera plugin's preview and so can only be
// named where that plugin compiles — behind the same conditional the scanner
// itself sits behind.
import 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder_stub.dart'
    if (dart.library.io) 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder_android.dart'
    as platform;

/// The live camera view for a scan in progress, or null where the scanner in
/// use has no live view to show — the web build's single photograph, or a
/// test double — in which case the sign-off card falls back to its
/// "reading the card" line.
Widget? buildCacViewfinder(CacScannerStrategy scanner) =>
    platform.buildCacViewfinder(scanner);
