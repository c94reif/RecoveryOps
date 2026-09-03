import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';

/// Styled text input field matching the Lattice design system.
///
/// Theme-aware — colors adapt when the active theme changes.
///
/// Pass [inputFormatters] to apply masking or filtering (e.g.
/// `MilitaryDateTimeFormatter`), and [keyboardType] to hint the soft keyboard
/// type (`TextInputType.number`, etc.).  Both parameters are purely additive —
/// omitting them leaves behaviour identical to the original widget.
class LatticeTextField extends StatelessWidget {
  const LatticeTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.isRequired = false,
    this.errorText,
    this.focusNode,
    this.inputFormatters,
    this.keyboardType,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;
  final bool isRequired;
  final String? errorText;
  final FocusNode? focusNode;

  /// Optional list of [TextInputFormatter]s applied to every edit.
  final List<TextInputFormatter>? inputFormatters;

  /// Overrides the soft-keyboard type shown for this field.
  final TextInputType? keyboardType;

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
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          enabled: enabled,
          focusNode: focusNode,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
              borderSide: BorderSide(
                  color: hasError ? colors.error : colors.borderActive),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
              borderSide: BorderSide(
                  color: hasError ? colors.error : colors.iconActive),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
              borderSide: BorderSide(color: colors.border),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LatticeSpacing.borderRadius),
              borderSide: BorderSide(
                  color: hasError ? colors.error : colors.borderActive),
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
