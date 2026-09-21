import 'package:flutter/material.dart';

import '../atoms/lattice_toggle_button.dart';
import '../tokens/lattice_spacing.dart';

/// Horizontal row of mutually exclusive [LatticeToggleButton]s.
///
/// Exactly one value should be selected at a time. Each button gets equal
/// flex width with [LatticeSpacing.sm] (8px) gaps between them.
class LatticeToggleGroup<T> extends StatelessWidget {
  const LatticeToggleGroup({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.variant = LatticeToggleVariant.accent,
    this.enabled = true,
    this.icons,
    this.height = LatticeSpacing.touchTarget,
  });

  final List<T> values;
  final List<String> labels;
  final T? selected;
  final ValueChanged<T> onChanged;
  final LatticeToggleVariant variant;
  final bool enabled;
  final List<IconData?>? icons;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: LatticeSpacing.sm),
          Expanded(
            child: LatticeToggleButton(
              label: labels[i],
              isSelected: values[i] == selected,
              onTap: enabled ? () => onChanged(values[i]) : () {},
              variant: variant,
              enabled: enabled,
              height: height,
              icon: icons != null && i < icons!.length ? icons![i] : null,
            ),
          ),
        ],
      ],
    );
  }
}
