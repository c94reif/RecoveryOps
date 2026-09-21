import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

/// Small uppercase heading above a group of controls, per the SDK style guide.
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: textSecondary,
      ),
    );
  }
}
