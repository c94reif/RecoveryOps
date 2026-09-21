import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';

/// Styled dropdown matching the Lattice design system.
///
/// Theme-aware — colors adapt when the active theme changes.
/// Height: 48px, border-radius: 8px.
class LatticeDropdown<T> extends StatelessWidget {
  const LatticeDropdown({
    super.key,
    this.label,
    this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.isRequired = false,
    this.errorText,
  });

  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool isRequired;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!.toUpperCase(),
                style: TextStyle(
                  color: colors.textLabel,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: LatticeSpacing.touchTarget,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
            border: Border.all(
                color: hasError ? colors.error : colors.borderActive),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
              ),
              iconEnabledColor: colors.textSecondary,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(
              color: colors.error,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
