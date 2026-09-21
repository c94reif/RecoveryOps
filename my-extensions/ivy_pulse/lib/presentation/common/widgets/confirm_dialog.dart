import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

/// Blocking yes/no gate for actions an operator cannot undo — abandoning a
/// walk-around, discarding a queued submission, clearing a recorded fault.
/// Dismissing the dialog counts as a refusal, never as a confirmation.
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
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
        ),
        SizedBox(
          height: minTouchTarget,
          child: TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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
