import 'package:flutter/material.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_aim_guide.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_note.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

class CacOcrPrompt extends StatelessWidget {
  final bool scansBothSides;
  final bool scannerAvailable;
  final bool isBusy;
  final VoidCallback onScan;
  final bool showAimGuide;
  final CacOcrText text;

  const CacOcrPrompt({
    super.key,
    required this.scansBothSides,
    required this.scannerAvailable,
    required this.isBusy,
    required this.onScan,
    this.showAimGuide = true,
    this.text = const CacOcrText(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final intro = scansBothSides ? text.promptBothSides : text.promptBackOnly;
    final noCamera = text.noCamera;
    final aside = <Widget>[
      if (scannerAvailable && showAimGuide)
        CacAimGuide(scansBothSides: scansBothSides, text: text)
      else if (!scannerAvailable && noCamera != null)
        CacNote(
          icon: Icons.no_photography_outlined,
          text: noCamera,
          color: theme.warning,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro != null)
          Text(
            intro,
            style: TextStyle(color: theme.mutedText, fontSize: 12, height: 1.4),
          ),
        if (intro != null && aside.isNotEmpty)
          SizedBox(height: scannerAvailable ? 10 : 8),
        ...aside,
        if (intro != null || aside.isNotEmpty) const SizedBox(height: 12),
        CacButton(
          text: text.scanButton,
          icon: Icons.badge_outlined,
          onPressed: isBusy ? null : onScan,
        ),
      ],
    );
  }
}
