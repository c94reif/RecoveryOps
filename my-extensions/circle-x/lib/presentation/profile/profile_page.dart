import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
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

  void onFieldChanged() => viewModel.checkDirty(uicController.text);

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
        return Container(
          padding: const EdgeInsets.all(5),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: uicController,
                      label: 'UIC',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      icon: Icons.groups_outlined,
                      hint: 'W12ABC',
                      textCapitalization: TextCapitalization.characters,
                      uppercase: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The only thing this device remembers about you. Who '
                      'walked the vehicle is read off your CAC when you close '
                      'the PMCS out.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (viewModel.isDirty)
                      CustomButton(
                        text:
                            viewModel.hasExistingProfile ? 'Save Edit' : 'Save',
                        onPressed: () => viewModel.save(uicController.text),
                      ),
                    const SizedBox(height: 32),
                    const SectionLabel(text: 'MAINTENANCE'),
                    const SizedBox(height: 8),
                    const Text(
                      'Review vehicle faults and the latest PMCS reports.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() => maintainerMode = true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dashBlue,
                          side: const BorderSide(color: dashBlue),
                          minimumSize: const Size.fromHeight(minTouchTarget),
                        ),
                        icon: const Icon(Icons.build_outlined, size: 18),
                        label: const Text('Enter maintainer mode'),
                      ),
                    ),
                    SizedBox(height: bottomInset),
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
