import 'package:flutter/material.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

enum CacTone { neutral, success, warning, danger }

class CacPanel extends StatelessWidget {
  final CacTone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final double radius;

  const CacPanel({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderWidth = 1.5,
    this.radius = 8,
  });

  const CacPanel.compact({super.key, required this.tone, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        borderWidth = 1,
        radius = 6;

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final (edge, fill) = switch (tone) {
      CacTone.neutral => (theme.outline, theme.surface),
      CacTone.success => (theme.success, theme.successContainer),
      CacTone.warning => (theme.warning, theme.warningContainer),
      CacTone.danger => (theme.danger, theme.dangerContainer),
    };
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge, width: borderWidth),
      ),
      child: child,
    );
  }
}
