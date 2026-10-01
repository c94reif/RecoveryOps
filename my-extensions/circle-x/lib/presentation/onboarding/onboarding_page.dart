import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
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

  bool get canContinue => uicController.text.trim().isNotEmpty && !isSaving;

  Future<void> submit() async {
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
    if (viewModel.savedUic.isEmpty) {
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
                  const SectionLabel(text: 'UIC'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: uicController,
                    label: 'UIC',
                    icon: Icons.groups_outlined,
                    hint: 'W12ABC',
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The unit you are signed for. It routes every 5988-E you '
                    'submit and fills itself in on every PMCS from here on. '
                    'Change it any time under Profile.',
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
