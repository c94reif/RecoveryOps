import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';

/// Asks for the UIC once, on a device that has never been set up.
///
/// It is the only thing Ivy Pulse needs before a walk-around and the only
/// thing it cannot work out for itself: the vehicle comes off the setup
/// screen, and who signed for it comes off the CAC at sign-off. Asking here
/// means the first PMCS of the day is one field shorter instead of stopping
/// on a blank the operator has to go find.
class OnboardingPage extends StatefulWidget {
  /// Called once the UIC is saved. The gate swaps in the real shell.
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
    } catch (e) {
      // A UIC that will not store is worth saying out loud — the operator can
      // retry, and the alternative is a screen that swallows the tap.
      debugPrint('[IvyPulse] onboarding save failed: $e');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the UIC — try again')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => isSaving = false);
    // save() refuses an empty UIC and says so rather than storing it; leave
    // the operator here to fix it instead of walking them into a PMCS with
    // nothing to route it by.
    if (viewModel.savedUic.isEmpty) {
      final message = viewModel.snackBarMessage ?? 'UIC is required';
      viewModel.snackBarMessage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    // Swallow the "Profile Saved!" toast — the screen changing says it.
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IVY PULSE',
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
