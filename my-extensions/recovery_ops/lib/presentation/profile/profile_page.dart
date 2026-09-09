import 'package:flutter/material.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_text_field.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_button.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final ProfileViewModel viewModel;
  final nameController = TextEditingController();
  final callSignController = TextEditingController();
  final unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel = getIt<ProfileViewModel>();

    nameController.addListener(onFieldChanged);
    callSignController.addListener(onFieldChanged);
    unitController.addListener(onFieldChanged);

    viewModel.addListener(handleSnackBar);

    viewModel.loadProfile().then((_) {
      nameController.text = viewModel.savedName;
      callSignController.text = viewModel.savedCallSign;
      unitController.text = viewModel.savedUnit;
    });
  }

  void onFieldChanged() {
    viewModel.checkDirty(
      nameController.text,
      callSignController.text,
      unitController.text,
    );
  }

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
    nameController.dispose();
    callSignController.dispose();
    unitController.dispose();
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
                  children: [
                    CustomTextField(
                      controller: nameController,
                      label: 'Name',
                      icon: Icons.person_outline,
                    ),
                    // TODO: Don't forget to eventually go back and refactor
                    // all the other code that deals with call sign in VM's
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: unitController,
                      label: 'Unit',
                      icon: Icons.groups_outlined,
                    ),
                    const SizedBox(height: 28),
                    if (viewModel.isDirty)
                      CustomButton(
                        text:
                            viewModel.hasExistingProfile ? 'Save Edit' : 'Save',
                        onPressed: () => viewModel.save(
                          nameController.text.trim(),
                          callSignController.text.trim(),
                          unitController.text.trim(),
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
