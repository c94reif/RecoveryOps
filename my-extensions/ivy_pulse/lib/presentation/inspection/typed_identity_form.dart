import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

/// The typed fallback on the sign-off card: name and DoD ID entered by hand
/// after the CAC would not read.
///
/// Sits below the scan-again / submit-unverified controls, because it is the
/// third choice, not the first — a scan that reads is always better than a
/// name taken on trust, and a maintainer would rather have the scan. But it
/// beats the fourth choice, which is a report signed by nobody.
///
/// Own widget rather than part of [SignOffCard] so the card stays stateless;
/// the controllers live here and die with the form.
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
    for (final c in [
      lastNameController,
      firstNameController,
      dodIdController
    ]) {
      c.addListener(onFieldChanged);
    }
  }

  void onFieldChanged() => setState(() {});

  /// Live on the button only once every field has *something* in it. The
  /// real validation — ten digits, a DoD ID in the range DEERS issues — is
  /// the view model's, and its answer comes back as a snack bar.
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

  /// A DoD ID is exactly ten digits.
  static const int dodIdLength = 10;

  /// Digits typed so far — spaces and dashes are ignored here exactly as the
  /// parser ignores them, so the count the operator watches is the count
  /// that will be judged.
  int get dodIdDigits =>
      dodIdController.text.replaceAll(RegExp(r'\D'), '').length;

  /// `7/10` beside the field, live as they type. Green once it is complete,
  /// amber while it is short, red once it is over — the wrong number of
  /// digits is the mistake a gloved thumb makes most, and it is far cheaper
  /// to see it at the seventh digit than at the submit button.
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
