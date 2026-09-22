import 'package:flutter/widgets.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

/// No live view on this platform — the web build photographs the card
/// through the system camera app and has nothing to draw in the meantime.
Widget? buildCacViewfinder(CacScannerStrategy scanner) => null;
