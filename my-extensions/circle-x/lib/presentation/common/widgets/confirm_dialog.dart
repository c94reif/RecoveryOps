import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        ),
        SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? redXRed : masterChiefGreen,
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
