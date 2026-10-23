import 'package:flutter/material.dart';
import 'package:cac_ocr/src/domain/dod_id.dart';
import 'package:cac_ocr/src/presentation/widgets/cac_button.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';

typedef CacTypedIdentitySubmit = Future<void> Function({
  required String lastName,
  required String firstName,
  required String dodId,
});

class CacTypedIdentityForm extends StatefulWidget {
  final CacTypedIdentitySubmit onSubmit;
  final bool isBusy;
  final CacOcrText text;

  const CacTypedIdentityForm({
    super.key,
    required this.onSubmit,
    required this.isBusy,
    this.text = const CacOcrText(),
  });

  @override
  State<CacTypedIdentityForm> createState() => _CacTypedIdentityFormState();
}

class _CacTypedIdentityFormState extends State<CacTypedIdentityForm> {
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
      !widget.isBusy;

  Future<void> submit() => widget.onSubmit(
        lastName: lastNameController.text,
        firstName: firstNameController.text,
        dodId: dodIdController.text,
      );

  int get dodIdDigits => DodId.digitsOf(dodIdController.text).length;

  Widget buildDodIdCounter(CacOcrTheme theme) {
    final digits = dodIdDigits;
    final color = switch (digits) {
      DodId.length => theme.success,
      > DodId.length => theme.danger,
      _ => theme.warning,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        '$digits/${DodId.length}',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget buildField(
    TextEditingController controller, {
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        helperMaxLines: 2,
        errorMaxLines: 2,
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
    final theme = CacOcrTheme.of(context);
    final text = widget.text;
    final heading = text.typedHeading;
    final notice = text.typedNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading != null) ...[
          Text(
            heading.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: theme.mutedText,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (notice != null) ...[
          Text(
            notice,
            style: TextStyle(color: theme.mutedText, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 8),
        ],
        buildField(
          lastNameController,
          label: text.lastNameLabel,
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        buildField(
          firstNameController,
          label: text.firstNameLabel,
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        buildField(
          dodIdController,
          label: text.dodIdLabel,
          hint: text.dodIdHint,
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          suffixIcon: buildDodIdCounter(theme),
        ),
        const SizedBox(height: 10),
        CacButton(
          text: text.typedSubmitButton,
          icon: Icons.edit_outlined,
          color: theme.warning,
          onPressed: canSubmit ? submit : null,
        ),
      ],
    );
  }
}
