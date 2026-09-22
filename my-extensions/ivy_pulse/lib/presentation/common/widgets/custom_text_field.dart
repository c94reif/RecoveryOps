import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final Widget? suffixIcon;
  final String? hint;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Which keyboard comes up. A DoD ID wants the number pad; a name does not.
  final TextInputType? keyboardType;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool uppercase;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.suffixIcon,
    this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.keyboardType,
    this.floatingLabelBehavior,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      keyboardType: keyboardType,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      inputFormatters: uppercase ? [UppercaseTextFormatter()] : null,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: floatingLabelBehavior,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Keep cursor offsets valid even for letters that expand when uppercased.
class UppercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = newValue.text;
    int offset(int value) =>
        value < 0 ? value : text.substring(0, value).toUpperCase().length;
    return newValue.copyWith(
      text: text.toUpperCase(),
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}
