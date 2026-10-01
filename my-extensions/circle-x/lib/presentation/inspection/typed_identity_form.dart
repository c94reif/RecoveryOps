import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';

class TypedIdentityForm extends StatefulWidget {
  final InspectionViewModel viewModel;

  const TypedIdentityForm({super.key, required this.viewModel});

  @override
  State<TypedIdentityForm> createState() => TypedIdentityFormState();
}

class TypedIdentityFormState extends State<TypedIdentityForm> {
  final lastNameController = TextEditingController();
  final firstNameController = TextEditingController();
  final dodIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      lastNameController,
      firstNameController,
      dodIdController
    ]) {
      controller.addListener(onFieldChanged);
    }
  }

  void onFieldChanged() => setState(() {});

  bool get canSubmit =>
      lastNameController.text.trim().isNotEmpty &&
      firstNameController.text.trim().isNotEmpty &&
      dodIdController.text.trim().isNotEmpty &&
      !widget.viewModel.isBusy;

  Future<void> submit() => widget.viewModel.submitAttested(
        lastName: lastNameController.text,
        firstName: firstNameController.text,
        edipi: dodIdController.text,
      );

  static const int dodIdLength = 10;

  int get dodIdDigits =>
      dodIdController.text.replaceAll(RegExp(r'\D'), '').length;

  Widget buildDodIdCounter() {
    final digits = dodIdDigits;
    final color = switch (digits) {
      dodIdLength => serviceableGreen,
      > dodIdLength => redXRed,
      _ => circleXAmber,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        '$digits/$dodIdLength',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  @override
  void dispose() {
    lastNameController.dispose();
    firstNameController.dispose();
    dodIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(text: 'OR TYPE IT IN'),
        const SizedBox(height: 4),
        const Text(
          'Goes out marked as typed, not scanned. The maintainer still gets a '
          'name and a number to chase.',
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: lastNameController,
          label: 'Last name',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: firstNameController,
          label: 'First name',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: dodIdController,
          label: 'DoD ID',
          hint: '10 digits',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          suffixIcon: buildDodIdCounter(),
        ),
        const SizedBox(height: 10),
        CustomButton(
          text: 'SUBMIT WITH TYPED ID',
          icon: Icons.edit_outlined,
          color: circleXAmber,
          onPressed: canSubmit ? submit : null,
        ),
      ],
    );
  }
}
