import 'package:flutter/widgets.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

import 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder_stub.dart'
    if (dart.library.io) 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder_android.dart'
    as platform;

Widget? buildCacViewfinder(CacScannerStrategy scanner) =>
    platform.buildCacViewfinder(scanner);
