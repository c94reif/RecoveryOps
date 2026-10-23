import 'package:flutter/material.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

class CacButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const CacButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          backgroundColor: tint.withValues(alpha: 0.15),
          side: BorderSide(color: tint, width: 1),
          disabledForegroundColor: theme.mutedText,
          disabledBackgroundColor: theme.surface,
          minimumSize: const Size.fromHeight(CacOcrTheme.minTouchTarget),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
