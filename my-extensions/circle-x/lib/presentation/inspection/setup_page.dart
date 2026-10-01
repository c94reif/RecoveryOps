import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_session.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';
import 'package:circle_x/presentation/inspection/bumper_scan_dialog.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => SetupPageState();
}

class SetupPageState extends State<SetupPage> {
  late final InspectionViewModel viewModel;
  final bumperNumberController = TextEditingController();
  final uicController = TextEditingController();
  final uicFocus = FocusNode();
  BumperScannerStrategy? bumperScanner;
  bool scanningBumper = false;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();
    if (getIt.isRegistered<BumperScannerStrategy>()) {
      bumperScanner = getIt<BumperScannerStrategy>();
    }

    prefillUic();
    applyPrefill();
    bumperNumberController.addListener(onFieldChanged);
    uicController.addListener(onFieldChanged);
    viewModel.addListener(prefillUic);
    viewModel.addListener(applyPrefill);
  }

  void prefillUic() {
    final uic = viewModel.profile?.uic ?? '';
    if (uic.isEmpty || uicController.text.isNotEmpty) return;
    uicController.text = uic;
  }

  void onFieldChanged() => setState(() {});

  void applyPrefill() {
    final prefill = viewModel.takePrefill();
    if (prefill == null) return;
    bumperNumberController.text = prefill.bumperNumber;
    uicController.text = prefill.uic;
  }

  bool get canBegin =>
      bumperNumberController.text.trim().isNotEmpty &&
      uicController.text.trim().isNotEmpty &&
      !viewModel.isBusy;

  Future<void> begin() async {
    await viewModel.beginSession(
      bumperNumber: bumperNumberController.text,
      uic: uicController.text,
    );
  }

  Future<void> scanBumperNumber() async {
    final scanner = bumperScanner;
    if (scanner == null || scanningBumper || viewModel.isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => scanningBumper = true);
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => BumperScanDialog(scanner: scanner),
    );
    if (!mounted) return;
    setState(() {
      scanningBumper = false;
      if (selected != null) bumperNumberController.text = selected;
    });
  }

  @override
  void dispose() {
    unawaited(bumperScanner?.dispose());
    viewModel.removeListener(prefillUic);
    viewModel.removeListener(applyPrefill);
    bumperNumberController.dispose();
    uicController.dispose();
    uicFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            if (viewModel.openSessions.isNotEmpty) ...[
              const SectionLabel(text: 'RESUME PMCS'),
              const SizedBox(height: 6),
              for (final open in viewModel.openSessions) buildResumeCard(open),
              const SizedBox(height: 20),
            ],
            const SectionLabel(text: 'VEHICLE PLATFORM'),
            const SizedBox(height: 8),
            buildVehicleSelector(),
            const SizedBox(height: 24),
            CustomTextField(
              controller: bumperNumberController,
              label: 'Bumper Number',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              icon: Icons.directions_car_outlined,
              textCapitalization: TextCapitalization.characters,
              uppercase: true,
              suffixIcon: bumperScanner?.isSupported == true
                  ? IconButton(
                      tooltip: 'Scan bumper number',
                      icon: const Icon(Icons.document_scanner_outlined),
                      onPressed: scanningBumper || viewModel.isBusy
                          ? null
                          : scanBumperNumber,
                    )
                  : null,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => uicFocus.requestFocus(),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: uicController,
              focusNode: uicFocus,
              label: 'UIC',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              icon: Icons.groups_outlined,
              textCapitalization: TextCapitalization.characters,
              uppercase: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 28),
            CustomButton(
              text: 'BEGIN PMCS',
              icon: Icons.play_arrow,
              onPressed: canBegin ? begin : null,
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget buildVehicleSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<VehicleType>(
        showSelectedIcon: false,
        segments: [
          for (final vehicle in viewModel.catalogSource.supportedVehicles)
            ButtonSegment(
              value: vehicle,
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    vehicle.technicalManual,
                    style: const TextStyle(fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
        selected: {viewModel.selectedVehicle},
        onSelectionChanged: (selection) =>
            viewModel.selectVehicle(selection.first),
      ),
    );
  }

  Widget buildResumeCard(PmcsSession open) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: circleXGlow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: circleXAmber, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => viewModel.resumeSession(open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.history, color: circleXAmber, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      open.displayTitle,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      open.uic,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (open.completedPhases.isNotEmpty)
                      Wrap(
                        children: [
                          for (final phase in open.completedPhases)
                            buildPhaseChip(phase),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      open.hasStartedAnyPhase
                          ? 'Ready to submit'
                          : 'Continue inspection',
                      style: const TextStyle(
                        color: circleXAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: circleXAmber, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPhaseChip(PmcsPhase phase) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: serviceableGlow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: serviceableGreen, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: serviceableGreen, size: 11),
            const SizedBox(width: 3),
            Text(
              phase.shortLabel,
              style: const TextStyle(
                color: serviceableGreen,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
