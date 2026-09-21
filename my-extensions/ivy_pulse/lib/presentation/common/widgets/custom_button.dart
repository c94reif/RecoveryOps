import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;

  /// Null disables the button, the same as any Material control.
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          backgroundColor: tint.withValues(alpha: 0.15),
          side: BorderSide(color: tint, width: 1),
          disabledForegroundColor: textSecondary,
          disabledBackgroundColor: surface,
          // Gloved fingers on a jolting vehicle miss anything shorter.
          minimumSize: const Size.fromHeight(minTouchTarget),
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
