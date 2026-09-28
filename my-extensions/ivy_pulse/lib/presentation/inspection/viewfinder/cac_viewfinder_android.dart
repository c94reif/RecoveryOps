import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/core/platform/cac_camera_preview.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

Widget? buildCacViewfinder(CacScannerStrategy scanner) => switch (scanner) {
      CacCameraPreview preview => CacViewfinder(scanner: preview),
      _ => null,
    };

class CacViewfinder extends StatelessWidget {
  final CacCameraPreview scanner;

  const CacViewfinder({super.key, required this.scanner});

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

class CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = masterChiefGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const bracketLength = 22.0;
    final width = size.width, height = size.height;
    final corners = <List<Offset>>[
      [
        const Offset(0, bracketLength),
        Offset.zero,
        const Offset(bracketLength, 0)
      ],
      [
        Offset(width - bracketLength, 0),
        Offset(width, 0),
        Offset(width, bracketLength)
      ],
      [
        Offset(width, height - bracketLength),
        Offset(width, height),
        Offset(width - bracketLength, height)
      ],
      [
        Offset(bracketLength, height),
        Offset(0, height),
        Offset(0, height - bracketLength)
      ],
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
