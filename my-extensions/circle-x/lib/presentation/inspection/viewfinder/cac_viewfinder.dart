import 'package:flutter/widgets.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';

import 'package:circle_x/presentation/inspection/viewfinder/cac_viewfinder_stub.dart'
    if (dart.library.io) 'package:circle_x/presentation/inspection/viewfinder/cac_viewfinder_android.dart'
    as platform;

Widget? buildCacViewfinder(CacScannerStrategy scanner) =>
    platform.buildCacViewfinder(scanner);

bool scansBothCacSides(CacScannerStrategy scanner) =>
    platform.scansBothCacSides(scanner);
