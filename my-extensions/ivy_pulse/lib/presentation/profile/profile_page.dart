import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final ProfileViewModel viewModel;
  final uicController = TextEditingController();

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
    final msg = viewModel.snackBarMessage;
    if (msg != null && mounted) {
      viewModel.snackBarMessage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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
