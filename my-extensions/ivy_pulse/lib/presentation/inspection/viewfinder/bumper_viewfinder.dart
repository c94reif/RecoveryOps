import 'package:flutter/widgets.dart';
import 'package:ivy_pulse/domain/services/bumper_scanner_strategy.dart';
import 'package:ivy_pulse/presentation/inspection/viewfinder/bumper_viewfinder_stub.dart'
    if (dart.library.io) 'package:ivy_pulse/presentation/inspection/viewfinder/bumper_viewfinder_android.dart'
    as platform;

Widget? buildBumperViewfinder(BumperScannerStrategy scanner) =>
    platform.buildBumperViewfinder(scanner);
