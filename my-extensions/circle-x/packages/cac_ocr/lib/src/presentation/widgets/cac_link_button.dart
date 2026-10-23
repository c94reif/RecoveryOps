import 'package:flutter/material.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

class CacLinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;

  const CacLinkButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: CacOcrTheme.minTouchTarget,
          child: TextButton(
            onPressed: onPressed,
            style: color == null
                ? null
                : TextButton.styleFrom(foregroundColor: color),
            child: Text(text),
          ),
        ),
      );
}
