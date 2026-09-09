import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/app_theme.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/repositories/location_repo.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_text_field.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_button.dart';
import 'package:recovery_ops/presentation/recovery/recovery_view_model.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});

  @override
  State<RecoveryPage> createState() => RecoveryPageState();
}

class RecoveryPageState extends State<RecoveryPage> {
  late final RecoveryViewModel recoveryViewModel;
  final bumperNumberController = TextEditingController();
  final issueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    recoveryViewModel = getIt<RecoveryViewModel>();
    recoveryViewModel.addListener(handleViewModelUpdate);
  }

  void handleViewModelUpdate() {
    if (recoveryViewModel.bumperResult != null) {
      bumperNumberController.text = recoveryViewModel.bumperResult!;
      recoveryViewModel.bumperResult = null;
    }
    if (recoveryViewModel.issueResult != null) {
      issueController.text = recoveryViewModel.issueResult!;
      recoveryViewModel.issueResult = null;
    }
  }

  void submit() async {
    final bumper = bumperNumberController.text;
    final issue = issueController.text;
    debugPrint('[RecoveryOps] Submit tapped — bumper="$bumper", '
        'issue="$issue", type=${recoveryViewModel.selectedType}');

    if (!recoveryViewModel.validate(bumper, issue)) {
      debugPrint('[RecoveryOps] Submit aborted — validation failed '
          '(bumper and/or issue empty)');
      return;
    }

    try {
      final loc = await getIt<LocationRepository>().getCurrentLocation();
      debugPrint('[RecoveryOps] Submit location — '
          '${loc == null ? 'null (falling back to 0,0)' : '${loc.latitude}, ${loc.longitude}'}');
      final position = loc ?? const LatLng(0, 0);

      await recoveryViewModel.submitRecoveryRequest(
        bumperNumber: bumper.trim(),
        issue: issue.trim(),
        type: recoveryViewModel.selectedType,
        position: position,
      );

      bumperNumberController.clear();
      issueController.clear();
      recoveryViewModel.onSubmitSuccess();
      debugPrint('[RecoveryOps] Submit complete — fields cleared');
    } catch (e, st) {
      debugPrint('[RecoveryOps] Submit FAILED — $e\n$st');
    }
  }

  Widget buildMicButton(String field, TextEditingController controller) {
    final isActive = recoveryViewModel.isListening &&
        recoveryViewModel.listeningField == field;
    const recordingRed = Color(0xFFE53935);
    return IconButton(
      onPressed: () => recoveryViewModel.toggleFieldListening(
        field,
        (text) => controller.text = text,
      ),
      icon: Icon(
        isActive ? Icons.mic : Icons.mic_none,
        color: isActive ? recordingRed : masterChiefGreen,
        size: 24,
      ),
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? recordingRed.withAlpha(38) : Colors.transparent,
        shape: const CircleBorder(),
      ),
      tooltip: isActive ? 'Recording — tap to stop' : 'Tap to record',
    );
  }

  @override
  void dispose() {
    recoveryViewModel.removeListener(handleViewModelUpdate);
    bumperNumberController.dispose();
    issueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ListenableBuilder(
      listenable: recoveryViewModel,
      builder: (context, _) {
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
                      controller: bumperNumberController,
                      label: 'Bumper Number',
                      icon: Icons.directions_car_outlined,
                      suffixIcon: buildMicButton(
                        'bumper',
                        bumperNumberController,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: issueController,
                      label: 'Issue',
                      icon: Icons.report_problem_outlined,
                      suffixIcon: buildMicButton(
                        'issue',
                        issueController,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recovery Type',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<RecoveryType>(
                        segments: const [
                          ButtonSegment(
                            value: RecoveryType.towBar,
                            label: Text('Tow Bar'),
                            icon: Icon(Icons.change_history),
                          ),
                          ButtonSegment(
                            value: RecoveryType.wrecker,
                            label: Text('Wrecker'),
                            icon: Icon(Icons.local_shipping_outlined),
                          ),
                        ],
                        selected: {recoveryViewModel.selectedType},
                        onSelectionChanged: (Set<RecoveryType> selection) {
                          recoveryViewModel.selectType(selection.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    CustomButton(
                      text: 'Submit Recovery Request',
                      onPressed: submit,
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
