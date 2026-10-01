import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/uic_text_field.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => OnboardingPageState();
}

class OnboardingPageState extends State<OnboardingPage> {
  late final ProfileViewModel viewModel;
  final uicController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ProfileViewModel>();
    uicController.addListener(onFieldChanged);
  }

  void onFieldChanged() => setState(() {});

  bool get canContinue => Uic.isValid(uicController.text) && !isSaving;

  Future<void> submit() async {
    if (!canContinue) return;
    setState(() => isSaving = true);
    try {
      await viewModel.save(uicController.text);
    } catch (error) {
      debugPrint('[CircleX] onboarding save failed: $error');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the UIC — try again')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => isSaving = false);
    if (!Uic.isValid(viewModel.savedUic)) {
      final message = viewModel.snackBarMessage ?? 'UIC is required';
      viewModel.snackBarMessage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    viewModel.snackBarMessage = null;
    widget.onComplete();
  }

  @override
  void dispose() {
    uicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 88,
                    height: 88,
                    semanticLabel: 'circle-x logo',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CIRCLE-X',
                    style: TextStyle(
                      color: masterChiefGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One thing before your first walk-around.',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel(text: 'INSPECTION DEFAULTS'),
                  const SizedBox(height: 8),
                  UicTextField(
                    controller: uicController,
                    label: 'Default UIC',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This UIC fills in automatically for a new PMCS. You can '
                    'change it during setup for each inspection, or update '
                    'your default any time in Profile.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  CustomButton(
                    text: isSaving ? 'SAVING…' : 'CONTINUE',
                    icon: Icons.arrow_forward,
                    onPressed: canContinue ? submit : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
