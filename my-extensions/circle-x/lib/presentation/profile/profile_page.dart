import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/uic.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/uic_text_field.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/maintainer/maintainer_page.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final ProfileViewModel viewModel;
  final uicController = TextEditingController();
  bool maintainerMode = false;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ProfileViewModel>();

    uicController.addListener(onFieldChanged);

    viewModel.addListener(handleSnackBar);

    viewModel.loadProfile().then((_) {
      if (!mounted) return;
      uicController.text = viewModel.savedUic;
      setState(() {});
      onFieldChanged();
    });
  }

  void onFieldChanged() {
    viewModel.checkDirty(uicController.text);
    setState(() {});
  }

  void handleSnackBar() {
    final snackBarMessage = viewModel.snackBarMessage;
    if (snackBarMessage != null && mounted) {
      viewModel.snackBarMessage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackBarMessage)),
      );
    }
  }

  @override
  void dispose() {
    viewModel.removeListener(handleSnackBar);
    uicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (maintainerMode) {
      return MaintainerPage(
        onExit: () => setState(() => maintainerMode = false),
      );
    }
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text(
                        'Profile',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your defaults and maintenance tools.',
                      style: _bodyStyle,
                    ),
                    const SizedBox(height: 24),
                    _ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            icon: Icons.tune,
                            title: 'Inspection defaults',
                            subtitle: 'Saved on this device',
                          ),
                          const SizedBox(height: 24),
                          UicTextField(
                            controller: uicController,
                            label: 'Default UIC',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Automatically filled in for a new PMCS. You can '
                            'change it during setup for each inspection.',
                            style: _bodyStyle,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: dashGlow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 18, color: dashBlue),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Existing inspections and reports keep '
                                    'their UIC.',
                                    style: _bodyStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (viewModel.isDirty) ...[
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'Save default UIC',
                              icon: Icons.check,
                              onPressed: Uic.isValid(uicController.text)
                                  ? () {
                                      FocusScope.of(context).unfocus();
                                      viewModel.save(uicController.text);
                                    }
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 22, color: textSecondary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Identity at sign-off',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your name and rank come from your CAC '
                                  'when you submit a PMCS.',
                                  style: _bodyStyle,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionLabel(text: 'MAINTENANCE'),
                    const SizedBox(height: 12),
                    _ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            icon: Icons.build_outlined,
                            title: 'Maintainer mode',
                            subtitle: 'Review vehicle faults and PMCS reports.',
                            color: dashBlue,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() => maintainerMode = true);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: dashBlue,
                                backgroundColor: dashGlow,
                                side: const BorderSide(color: dashBlue),
                                minimumSize:
                                    const Size.fromHeight(minTouchTarget),
                              ),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Enter maintainer mode'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const _bodyStyle = TextStyle(
  color: textSecondary,
  fontSize: 13,
  height: 1.45,
);

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgDark,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = serviceableGreen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: _bodyStyle),
              ],
            ),
          ),
        ],
      );
}
