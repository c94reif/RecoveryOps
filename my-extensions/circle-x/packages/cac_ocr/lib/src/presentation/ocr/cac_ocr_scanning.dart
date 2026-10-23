import 'package:flutter/material.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_link_button.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_panel.dart';
import 'package:cac_ocr/src/presentation/viewfinder/cac_viewfinder.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

class CacOcrScanning extends StatelessWidget {
  final CacScannerStrategy scanner;
  final bool isBusy;
  final VoidCallback onCancel;
  final CacOcrText text;

  const CacOcrScanning({
    super.key,
    required this.scanner,
    required this.isBusy,
    required this.onCancel,
    this.text = const CacOcrText(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final notice = text.scanningNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCacViewfinder(scanner, text: text) ??
            CacPanel(
              tone: CacTone.neutral,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              borderWidth: 1,
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text.scanningFallback,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        CacLinkButton(
          text: text.cancelButton,
          onPressed: isBusy ? null : onCancel,
        ),
        if (notice != null)
          Text(
            notice,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText, fontSize: 11, height: 1.4),
          ),
      ],
    );
  }
}
