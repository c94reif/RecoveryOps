import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/presentation/inspection/viewfinder/cac_live_preview.dart';

class _PreviewCamera extends CameraController {
  _PreviewCamera()
      : super(
          const CameraDescription(
              name: 'rear',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90),
          ResolutionPreset.high,
        ) {
    value =
        value.copyWith(isInitialized: true, previewSize: const Size(640, 480));
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
}

void main() {
  testWidgets(
      'taps target the shown preview and rotation keeps its aspect correct',
      (tester) async {
    final camera = _PreviewCamera();
    final taps = <Offset>[];
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
      width: 320,
      height: 240,
      child: CacLivePreview(
        controller: camera,
        onFocus: (point) async => taps.add(point),
        guide: const SizedBox.expand(),
      ),
    ))));
    SizedBox previewSize() => tester.widget<SizedBox>(find
        .ancestor(
            of: find.byType(CameraPreview), matching: find.byType(SizedBox))
        .first);
    expect(previewSize().width, 480);
    expect(previewSize().height, 640);
    final origin = tester.getTopLeft(find.byType(CacLivePreview));
    await tester.tapAt(origin + const Offset(80, 60));
    await tester.pump();
    expect(taps, [const Offset(0.25, 0.25)]);
    camera.value = camera.value
        .copyWith(deviceOrientation: DeviceOrientation.landscapeLeft);
    await tester.pump();
    expect(previewSize().width, 640);
    expect(previewSize().height, 480);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await camera.dispose();
  });
}
