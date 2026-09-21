import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

/// Tap-to-pick alternative to typing, for a field whose values come off a
/// fixed roster — an operator in gloves should not have to work a soft
/// keyboard for something with a known answer.
class QuickPickChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const QuickPickChips({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () => onSelected(option),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: minTouchTarget),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: option == selected ? greenGlow : surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: option == selected ? primary : border,
                  width: 1,
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: option == selected ? primary : textPrimary,
                  fontSize: 14,
                  fontWeight:
                      option == selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
