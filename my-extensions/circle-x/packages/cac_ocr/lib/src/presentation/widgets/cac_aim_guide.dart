import 'package:flutter/material.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

class CacAimGuide extends StatelessWidget {
  final bool scansBothSides;
  final CacOcrText text;

  const CacAimGuide({
    super.key,
    required this.scansBothSides,
    this.text = const CacOcrText(),
  });

  static const double cardWidth = 88;
  static const double cardHeight = cardWidth / 1.587;

  @override
  Widget build(BuildContext context) {
    final lines =
        scansBothSides ? text.aimGuideBothSides : text.aimGuideBackOnly;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCardSchematic(CacOcrTheme.of(context)),
        if (lines.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, line) in lines.indexed) ...[
                  if (index > 0) const SizedBox(height: 5),
                  _AimGuideLine(line),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget buildCardSchematic(CacOcrTheme theme) {
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
                color: theme.raisedSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.outline, width: 1),
              ),
            ),
          ),
          buildPrintedRule(theme, top: 0.10, width: 0.40),
          buildPrintedRule(theme, top: 0.20, width: 0.30),
          Positioned(
            left: width * 0.08,
            top: height * (scansBothSides ? 0.65 : 0.32),
            width: width * 0.62,
            height: height * 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: theme.success,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: theme.accent, width: 1.2),
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
                color: theme.outline,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          buildPrintedRule(theme, top: 0.86, width: 0.84),
        ],
      ),
    );
  }

  Widget buildPrintedRule(CacOcrTheme theme,
      {required double top, required double width}) {
    return Positioned(
      left: (scansBothSides ? cardHeight : cardWidth) * 0.08,
      top: (scansBothSides ? cardWidth : cardHeight) * top,
      width: (scansBothSides ? cardHeight : cardWidth) * width,
      height: 2,
      child: Container(color: theme.outline),
    );
  }
}

class _AimGuideLine extends StatelessWidget {
  final String text;

  const _AimGuideLine(this.text);

  @override
  Widget build(BuildContext context) {
    final mutedText = CacOcrTheme.of(context).mutedText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '·  ',
          style: TextStyle(color: mutedText, fontSize: 11, height: 1.3),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: mutedText,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
