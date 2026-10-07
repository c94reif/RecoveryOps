import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

/// A platform choice with the vehicle identity ahead of its manual metadata.
class VehiclePlatformCard extends StatelessWidget {
  final VehicleType vehicle;
  final bool selected;
  final VoidCallback? onTap;
  final bool opensPicker;

  const VehiclePlatformCard({
    super.key,
    required this.vehicle,
    required this.selected,
    required this.onTap,
    this.opensPicker = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF96D5A1);
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Material(
          color: selected ? const Color(0xFF202F27) : surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
                color: selected ? serviceableGreen : border,
                width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlatformGraphic(vehicle: vehicle, selected: selected),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (opensPicker) ...[
                              const Text('CURRENT PLATFORM',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1)),
                              const SizedBox(height: 4),
                            ],
                            Text(vehicle.displayName,
                                style: TextStyle(
                                    color: textPrimary,
                                    fontSize: opensPicker ? 24 : 21,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    letterSpacing: -.3)),
                            const SizedBox(height: 5),
                            Text(vehicle.variant,
                                style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                      if (!opensPicker) ...[
                        const SizedBox(width: 8),
                        Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? accent : textSecondary,
                            size: 22),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgDark.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            color: textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(vehicle.technicalManual,
                              style: const TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  height: 1.35)),
                        ),
                        if (opensPicker) ...[
                          const SizedBox(width: 8),
                          const Text('Change',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more_rounded,
                              color: accent, size: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformGraphic extends StatelessWidget {
  final VehicleType vehicle;
  final bool selected;

  const _PlatformGraphic({required this.vehicle, required this.selected});

  @override
  Widget build(BuildContext context) {
    final family = vehicle.family.toLowerCase();
    final color = selected ? const Color(0xFFB7D4BE) : textSecondary;
    return ExcludeSemantics(
      child: Container(
        width: 76,
        height: 66,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? serviceableGlow : bgDark.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .12)),
        ),
        child: family == 'stryker' || family == 'jltv'
            ? CustomPaint(
                painter: _VehicleSilhouette(
                    stryker: family == 'stryker', color: color))
            : Icon(Icons.local_shipping_outlined, color: color, size: 34),
      ),
    );
  }
}

/// Decorative silhouettes; proportions do not encode vehicle specifications.
class _VehicleSilhouette extends CustomPainter {
  final bool stryker;
  final Color color;

  const _VehicleSilhouette({required this.stryker, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 64);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final hull = Path();
    if (stryker) {
      hull
        ..moveTo(8, 44)
        ..lineTo(18, 29)
        ..lineTo(66, 29)
        ..lineTo(81, 39)
        ..lineTo(94, 39)
        ..lineTo(91, 49)
        ..lineTo(8, 49)
        ..close();
      canvas.drawPath(
          Path()
            ..moveTo(31, 29)
            ..lineTo(36, 21)
            ..lineTo(56, 21)
            ..lineTo(61, 29),
          stroke);
      canvas.drawLine(const Offset(24, 36), const Offset(63, 36), stroke);
    } else {
      hull
        ..moveTo(8, 49)
        ..lineTo(8, 36)
        ..lineTo(18, 36)
        ..lineTo(26, 22)
        ..lineTo(51, 22)
        ..lineTo(66, 36)
        ..lineTo(86, 36)
        ..lineTo(94, 42)
        ..lineTo(94, 49)
        ..close();
      canvas.drawPath(
          Path()
            ..moveTo(25, 35)
            ..lineTo(30, 26)
            ..lineTo(47, 26)
            ..lineTo(57, 35)
            ..close(),
          stroke);
      canvas.drawLine(const Offset(43, 26), const Offset(43, 43), stroke);
    }
    canvas.drawPath(hull, Paint()..color = color.withValues(alpha: .12));
    canvas.drawPath(hull, stroke);
    for (final x in stryker ? [21.0, 40.0, 61.0, 80.0] : [26.0, 77.0]) {
      canvas.drawCircle(Offset(x, 50), 7.5, Paint()..color = bgDark);
      canvas.drawCircle(Offset(x, 50), 7.5, stroke);
      canvas.drawCircle(Offset(x, 50), 2, Paint()..color = color);
    }
    canvas.drawLine(const Offset(8, 61), const Offset(94, 61),
        Paint()..color = color.withValues(alpha: .2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VehicleSilhouette oldDelegate) =>
      stryker != oldDelegate.stryker || color != oldDelegate.color;
}
