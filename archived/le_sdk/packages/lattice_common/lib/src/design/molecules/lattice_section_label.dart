import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';

/// Uppercase field label with optional red required-field marker.
///
/// Theme-aware — label color adapts to the active theme.
class LatticeSectionLabel extends StatelessWidget {
  const LatticeSectionLabel(
    this.text, {
    super.key,
    this.isRequired = false,
  });

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    if (!isRequired) {
      return Text(
        text,
        style: TextStyle(
          color: colors.textLabel,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: colors.textLabel,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          ' *',
          style: TextStyle(
            color: colors.error,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
