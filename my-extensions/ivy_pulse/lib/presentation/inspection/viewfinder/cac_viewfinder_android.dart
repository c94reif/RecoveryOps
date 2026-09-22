import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/data/services/android_cac_scanner.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

Widget? buildCacViewfinder(CacScannerStrategy scanner) =>
    scanner is AndroidCacScanner ? CacViewfinder(scanner: scanner) : null;

/// The live camera view during a scan, with a card-shaped box to fill and a
/// line of guidance beneath it that follows what the recogniser is seeing.
///
/// The box is the CR80 card ratio, landscape, because the back of a CAC is
/// printed landscape: filled edge to edge it puts the DoD ID number at a size
/// OCR reads on the first frame. There is no shutter — the scan ends itself
/// the moment the number is read — so the only control is CANCEL SCAN on the
/// card beneath this.
class CacViewfinder extends StatelessWidget {
  final AndroidCacScanner scanner;

  const CacViewfinder({super.key, required this.scanner});

  /// CR80 card, long edge over short.
  static const double cardAspect = 85.6 / 53.98;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraController?>(
      valueListenable: scanner.preview,
      builder: (context, controller, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                // Landscape frame for a landscape card; the preview is
                // cover-fitted into it so the box below is what the operator
                // fills, not the sensor's own aspect.
                aspectRatio: 4 / 3,
                child: controller == null || !controller.value.isInitialized
                    ? const ColoredBox(
                        color: surface,
                        child: Center(
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
                          FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: controller.value.previewSize?.height ?? 4,
                              height: controller.value.previewSize?.width ?? 3,
                              child: CameraPreview(controller),
                            ),
                          ),
                          const CardGuide(),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: scanner.guidance,
              builder: (_, text, __) => Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text == 'Read' ? serviceableGreen : textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A dimmed surround with a clear card-shaped window and bracketed corners —
/// the thing to line the back of the card up with.
class CardGuide extends StatelessWidget {
  const CardGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.86;
        final height = width / CacViewfinder.cardAspect;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Dim everything outside the window so the eye goes to it.
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.45),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: width,
                height: height,
                child: CustomPaint(painter: CornerBracketsPainter()),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text(
                'BACK OF CARD — DoD ID NUMBER ABOVE THE STRIP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Four green corner brackets, the universal "line it up here".
class CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = masterChiefGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;
    final w = size.width, h = size.height;
    final corners = <List<Offset>>[
      [const Offset(0, arm), Offset.zero, const Offset(arm, 0)],
      [Offset(w - arm, 0), Offset(w, 0), Offset(w, arm)],
      [Offset(w, h - arm), Offset(w, h), Offset(w - arm, h)],
      [Offset(arm, h), Offset(0, h), Offset(0, h - arm)],
    ];
    for (final corner in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(corner[0].dx, corner[0].dy)
          ..lineTo(corner[1].dx, corner[1].dy)
          ..lineTo(corner[2].dx, corner[2].dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CornerBracketsPainter oldDelegate) => false;
}
