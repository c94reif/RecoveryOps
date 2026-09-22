import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/display_mode.dart';
import 'package:ivy_pulse/presentation/common/fullscreen.dart';
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

  /// Testing control: cycle the UI through off → clockwise →
  /// counter-clockwise.
  void cycleVertical() {
    verticalQuarterTurns.value = switch (verticalQuarterTurns.value) {
      0 => 1,
      1 => 3,
      _ => 0,
    };
  }

  /// Testing control: take the whole device screen, or give it back.
  ///
  /// Must stay on the synchronous path out of the tap — [enterFullScreen]
  /// needs the user activation that tap carries, and an await before it would
  /// spend it.
  Future<void> toggleFullScreen() async {
    if (fullScreenOn.value) {
      // Deliberate: the next tap must not take the screen straight back.
      fullScreenWanted.value = false;
      await leaveFullScreen();
      return;
    }
    fullScreenWanted.value = true;
    final ok = await enterFullScreen();
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The host refused full screen')),
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
                    const SizedBox(height: 32),
                    const SectionLabel(text: 'TESTING'),
                    const SizedBox(height: 8),
                    const Text(
                      'Both are on by default: the UI opens portrait, and the '
                      'first touch anywhere takes the whole device — status '
                      'bar, map and nav rail included. These back them out, or '
                      'turn the rotation the other way if it reads upside '
                      'down.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Deliberately not CustomButtons: this is scaffolding, and
                    // the profile tests read the real UI by that type.
                    ValueListenableBuilder<bool>(
                      valueListenable: fullScreenOn,
                      builder: (context, on, _) => SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: toggleFullScreen,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: dashBlue,
                            side: const BorderSide(color: dashBlue),
                            minimumSize: const Size.fromHeight(minTouchTarget),
                          ),
                          icon: Icon(
                            on ? Icons.fullscreen_exit : Icons.fullscreen,
                            size: 18,
                          ),
                          label: Text(on ? 'Leave full screen' : 'Full screen'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: verticalQuarterTurns,
                      builder: (context, turns, _) => SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: cycleVertical,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: dashBlue,
                            side: const BorderSide(color: dashBlue),
                            minimumSize: const Size.fromHeight(minTouchTarget),
                          ),
                          icon: Icon(
                            turns == 0
                                ? Icons.screen_rotation
                                : Icons.screen_lock_rotation,
                            size: 18,
                          ),
                          label: Text(switch (turns) {
                            0 => 'Vertical',
                            1 => 'Turn the other way',
                            _ => 'Back to landscape',
                          }),
                        ),
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
