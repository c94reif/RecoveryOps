import 'package:flutter/widgets.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_camera_preview.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

import 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder_stub.dart'
    if (dart.library.io) 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder_live.dart'
    as platform;

Widget? buildCacViewfinder(CacScannerStrategy scanner,
        {CacOcrText text = const CacOcrText()}) =>
    platform.buildCacViewfinder(scanner, text: text);

bool scansBothCacSides(CacScannerStrategy scanner) => switch (scanner) {
      CacCameraPreview(sides: CacSides.frontAndBack) => true,
      _ => false,
    };

bool hasCacLivePreview(CacScannerStrategy scanner) =>
    scanner is CacCameraPreview;
