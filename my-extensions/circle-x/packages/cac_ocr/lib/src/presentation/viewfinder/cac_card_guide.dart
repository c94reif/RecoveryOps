import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_camera_geometry.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

class CacCardGuide extends StatelessWidget {
  final CacScanSide side;
  final CacOcrText text;

  final List<Rect> highlights;

  const CacCardGuide({
    super.key,
    required this.side,
    this.text = const CacOcrText(),
    this.highlights = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final front = side == CacScanSide.front;
        final card = CacCameraGeometry.guide(constraints.biggest, side);
        final width = card.width;
        final height = card.height;
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
                child: CustomPaint(
                  painter:
                      CornerBracketsPainter(CacOcrTheme.of(context).accent),
                  foregroundPainter: highlights.isEmpty
                      ? null
                      : ReadHighlightsPainter(
                          highlights, CacOcrTheme.of(context).success),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 10,
              child: Text(
                front ? text.frontGuideLabel : text.backGuideLabel,
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
  final Color color;

  CornerBracketsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(CornerBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ReadHighlightsPainter extends CustomPainter {
  final List<Rect> highlights;
  final Color color;

  ReadHighlightsPainter(this.highlights, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final rect in highlights) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rect.left * size.width, rect.top * size.height,
                  rect.right * size.width, rect.bottom * size.height)
              .inflate(2),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ReadHighlightsPainter oldDelegate) =>
      !listEquals(oldDelegate.highlights, highlights) ||
      oldDelegate.color != color;
}
