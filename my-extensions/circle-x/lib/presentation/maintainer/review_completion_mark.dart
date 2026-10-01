import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';

class ReviewCompletionMark extends StatelessWidget {
  final double progress;

  const ReviewCompletionMark({super.key, required this.progress});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: const Size(176, 176),
          painter: _CompletionPainter(progress),
        ),
      );
}

class _CompletionPainter extends CustomPainter {
  final double progress;
  const _CompletionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final burst = Curves.easeOutCubic.transform(progress);
    final arrival = Curves.easeOutBack
        .transform(const Interval(0, .65).transform(progress));
    final paint = Paint()..isAntiAlias = true;

    // A single outward pulse settles into a persistent completion badge.
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = serviceableGreen.withValues(alpha: (1 - burst) * .7);
    canvas.drawCircle(center, 42 + burst * 42, paint);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      paint
        ..strokeWidth = i.isEven ? 3 : 2
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? serviceableGreen : textPrimary)
            .withValues(alpha: math.sin(progress * math.pi) * .8);
      canvas.drawLine(center + direction * (48 + burst * 24),
          center + direction * (54 + burst * 30), paint);
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(arrival);
    paint
      ..style = PaintingStyle.fill
      ..color = serviceableGlow;
    canvas.drawCircle(Offset.zero, 44, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = serviceableGreen;
    canvas.drawCircle(Offset.zero, 44, paint);

    final check = Path()
      ..moveTo(-20, 0)
      ..lineTo(-5, 15)
      ..lineTo(22, -16);
    final metric = check.computeMetrics().single;
    final drawn =
        const Interval(.15, .65, curve: Curves.easeOut).transform(progress);
    paint
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..color = textPrimary;
    canvas.drawPath(metric.extractPath(0, metric.length * drawn), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompletionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
