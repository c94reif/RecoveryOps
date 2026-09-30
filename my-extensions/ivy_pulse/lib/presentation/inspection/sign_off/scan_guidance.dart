import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

class CacAimGuide extends StatelessWidget {
  final bool scansBothSides;

  const CacAimGuide({
    super.key,
    required this.scansBothSides,
  });

  static const double cardWidth = 88;
  static const double cardHeight = cardWidth / 1.587;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCardSchematic(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AimGuideLine(scansBothSides
                  ? '1. Show the front — your name below the photo'
                  : 'Turn the card over — the side the gate scans'),
              const SizedBox(height: 5),
              AimGuideLine(scansBothSides
                  ? '2. Flip when asked — DoD ID above the wide strip'
                  : 'Fill the box; the DoD ID number sits above the wide strip'),
              const SizedBox(height: 5),
              const AimGuideLine('It reads by itself — no button to press'),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCardSchematic() {
    final width = scansBothSides ? cardHeight : cardWidth;
    final height = scansBothSides ? cardWidth : cardHeight;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border, width: 1),
              ),
            ),
          ),
          buildPrintedRule(top: 0.10, width: 0.40),
          buildPrintedRule(top: 0.20, width: 0.30),
          Positioned(
            left: width * 0.08,
            top: height * (scansBothSides ? 0.65 : 0.32),
            width: width * 0.62,
            height: height * 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: serviceableGreen,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: masterChiefGreen, width: 1.2),
              ),
            ),
          ),
          Positioned(
            left: width * 0.08,
            top: height * (scansBothSides ? 0.30 : 0.58),
            width: width * (scansBothSides ? 0.44 : 0.84),
            height: height * (scansBothSides ? 0.28 : 0.14),
            child: Container(
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          buildPrintedRule(top: 0.86, width: 0.84),
        ],
      ),
    );
  }

  Widget buildPrintedRule({required double top, required double width}) {
    return Positioned(
      left: (scansBothSides ? cardHeight : cardWidth) * 0.08,
      top: (scansBothSides ? cardWidth : cardHeight) * top,
      width: (scansBothSides ? cardHeight : cardWidth) * width,
      height: 2,
      child: Container(color: border),
    );
  }
}

class CacGalleryAdvisory extends StatelessWidget {
  const CacGalleryAdvisory({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.photo_camera_back_outlined,
            color: circleXAmber, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Ivy Pulse dropped the photo, but the camera app may have kept its '
            'own copy in the gallery. Delete it there.',
            style: TextStyle(
              color: circleXAmber,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class AimGuideLine extends StatelessWidget {
  final String text;

  const AimGuideLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '·  ',
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
