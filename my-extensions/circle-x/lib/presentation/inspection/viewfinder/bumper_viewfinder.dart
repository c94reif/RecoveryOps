import 'package:flutter/widgets.dart';
import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';
import 'package:circle_x/presentation/inspection/viewfinder/bumper_viewfinder_stub.dart'
    if (dart.library.io) 'package:circle_x/presentation/inspection/viewfinder/bumper_viewfinder_android.dart'
    as platform;

Widget? buildBumperViewfinder(BumperScannerStrategy scanner) =>
    platform.buildBumperViewfinder(scanner);
