import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/pmcs_session.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_text_field.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

/// Picks the vehicle to walk. Resumable sessions sit above everything else —
/// a Soldier who was pulled off a PMCS should not start it over.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => SetupPageState();
}

class SetupPageState extends State<SetupPage> {
  late final InspectionViewModel viewModel;
  final bumperNumberController = TextEditingController();
  final uicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();

    prefillUic();
    bumperNumberController.addListener(onFieldChanged);
    uicController.addListener(onFieldChanged);
    viewModel.addListener(prefillUic);
  }

  /// The UIC on the profile is the one the operator is signed for, so it
  /// lands as soon as the profile does — still overridable for a vehicle
  /// borrowed from another company.
  void prefillUic() {
    final uic = viewModel.profile?.uic ?? '';
    if (uic.isEmpty || uicController.text.isNotEmpty) return;
    uicController.text = uic;
  }

  void onFieldChanged() => setState(() {});

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

  @override
  void dispose() {
    viewModel.removeListener(prefillUic);
    bumperNumberController.dispose();
    uicController.dispose();
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
            const SizedBox(height: 20),
            const SectionLabel(text: 'BUMPER NUMBER'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: bumperNumberController,
              label: 'Bumper Number',
              icon: Icons.directions_car_outlined,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            const SectionLabel(text: 'UIC'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: uicController,
              label: 'UIC',
              icon: Icons.groups_outlined,
              textCapitalization: TextCapitalization.characters,
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
                    Row(
                      children: [
                        for (final phase in PmcsPhase.values)
                          buildPhaseChip(phase, open.isPhaseComplete(phase)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${open.remainingPhases.length} phase(s) remaining',
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

  Widget buildPhaseChip(PmcsPhase phase, bool isComplete) {
    final color = isComplete ? serviceableGreen : textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isComplete ? serviceableGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isComplete) ...[
              const Icon(Icons.check, color: serviceableGreen, size: 11),
              const SizedBox(width: 3),
            ],
            Text(
              phase.shortLabel,
              style: TextStyle(
                color: color,
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
