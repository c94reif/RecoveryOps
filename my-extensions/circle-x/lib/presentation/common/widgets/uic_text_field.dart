import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:circle_x/domain/profile/entities/uic.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';

class UicTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final String label;

  const UicTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSubmitted,
    this.label = 'UIC',
  });

  @override
  State<UicTextField> createState() => _UicTextFieldState();
}

class _UicTextFieldState extends State<UicTextField> {
  bool edited = false;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final normalized = Uic.normalize(value.text);
          return CustomTextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            label: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            icon: Icons.groups_outlined,
            hint: 'W12ABC',
            helperText: '6 letters or numbers required',
            counterText: '${normalized.characters.length}/${Uic.length}',
            errorText: edited || value.text.isNotEmpty
                ? Uic.validate(value.text)
                : null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UicTextFormatter()],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => edited = true),
            onSubmitted:
                widget.onSubmitted ?? (_) => FocusScope.of(context).unfocus(),
          );
        },
      );
}

class _UicTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    int offset(int value) => value < 0
        ? value
        : Uic.normalize(newValue.text.substring(0, value)).length;
    return newValue.copyWith(
      text: Uic.normalize(newValue.text),
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
