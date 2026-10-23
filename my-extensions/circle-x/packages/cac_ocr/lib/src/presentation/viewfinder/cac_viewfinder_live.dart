import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_camera_geometry.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_camera_preview.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_live_feedback.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_card_guide.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_live_preview.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_torch_button.dart';

Widget? buildCacViewfinder(CacScannerStrategy scanner,
        {CacOcrText text = const CacOcrText()}) =>
    switch (scanner) {
      CacCameraPreview preview => CacViewfinder(scanner: preview, text: text),
      _ => null,
    };

class CacViewfinder extends StatelessWidget {
  final CacCameraPreview scanner;
  final CacOcrText text;

  const CacViewfinder(
      {super.key, required this.scanner, this.text = const CacOcrText()});

  static const double cardAspect = CacCameraGeometry.cardAspect;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CacScanSide>(
      valueListenable: scanner.side,
      builder: (context, side, _) => buildPreview(side),
    );
  }

  CacLiveFeedback? get feedback => switch (scanner) {
        CacLiveFeedback live => live,
        _ => null,
      };

  Widget buildPreview(CacScanSide side) {
    final live = feedback;
    return ValueListenableBuilder<CameraController?>(
      valueListenable: scanner.preview,
      builder: (context, controller, _) {
        final theme = CacOcrTheme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch ((scanner.sides, side)) {
                (CacSides.backOnly, _) => text.backOnlyStep,
                (_, CacScanSide.front) => text.frontStep,
                (_, CacScanSide.back) => text.backStep,
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: CacCameraGeometry.previewAspect,
                child: controller == null || !controller.value.isInitialized
                    ? ColoredBox(
                        color: theme.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CacLivePreview(
                            controller: controller,
                            onFocus: scanner.focusAt,
                            guide: live == null
                                ? CacCardGuide(side: side, text: text)
                                : ValueListenableBuilder<List<Rect>>(
                                    valueListenable: live.highlights,
                                    builder: (_, highlights, __) =>
                                        CacCardGuide(
                                      side: side,
                                      text: text,
                                      highlights: highlights,
                                    ),
                                  ),
                          ),
                          if (live != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CacTorchButton(live: live, text: text),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              side == CacScanSide.front
                  ? text.frontFocusHint
                  : text.backFocusHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.mutedText, fontSize: 11),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<CacGuidance>(
              valueListenable: scanner.guidance,
              builder: (_, guidance, __) => Semantics(
                liveRegion: true,
                child: Text(
                  text.guidance(guidance),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: guidance == CacInstruction.cardRead
                        ? theme.success
                        : theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
