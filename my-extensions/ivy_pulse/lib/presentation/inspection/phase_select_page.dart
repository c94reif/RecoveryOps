import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

/// The three TM phases. A completed phase stays open for review because the
/// operator is the one who signs the 5988-E and may want to re-read it.
class PhaseSelectPage extends StatefulWidget {
  const PhaseSelectPage({super.key});

  @override
  State<PhaseSelectPage> createState() => PhaseSelectPageState();
}

class PhaseSelectPageState extends State<PhaseSelectPage> {
  late final InspectionViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();
  }

  Future<void> discard() async {
    final session = viewModel.session;
    if (session == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard PMCS?',
      message: 'Every check recorded on ${session.bumperNumber} will be '
          'deleted. This cannot be undone.',
      confirmLabel: 'DISCARD',
      destructive: true,
    );
    if (!confirmed) return;

    await viewModel.discardSession();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final session = viewModel.session;
        if (session == null) return const SizedBox.shrink();

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Text(
              session.displayTitle,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${session.uic} · ${session.vehicleType.technicalManual}',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const SectionLabel(text: 'SELECT PHASE'),
            const SizedBox(height: 8),
            for (final phase in PmcsPhase.values)
              buildPhaseCard(phase, session.isPhaseComplete(phase)),
            const SizedBox(height: 20),
            if (session.hasStartedAnyPhase)
              CustomButton(
                text: 'VIEW PMCS SUMMARY',
                icon: Icons.assignment_outlined,
                onPressed: viewModel.openSummary,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: discard,
              child: const Text('DISCARD SESSION'),
            ),
          ],
        );
      },
    );
  }

  Widget buildPhaseCard(PmcsPhase phase, bool isComplete) {
    final itemCount = viewModel.catalog?.itemCountFor(phase) ?? 0;
    final accent = isComplete ? serviceableGreen : masterChiefGreen;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: accent, width: isComplete ? 1.5 : 1),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => viewModel.openPhase(phase),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase.label,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount ${itemCount == 1 ? 'check' : 'checks'}',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: serviceableGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'COMPLETE',
                          style: TextStyle(
                            color: serviceableGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    )
                  else
                    Icon(Icons.chevron_right, color: accent, size: 24),
                ],
              ),
            ),
          ),
          // A RED X recorded in this phase, pinned to the card's corner so it
          // reads at a glance even once the phase is closed out and the row
          // is busy saying COMPLETE. Red because the vehicle is deadlined by
          // it, and the operator choosing which phase to open next should
          // know which one holds the fault.
          if (hasRedX(phase))
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.cancel, color: redXRed, size: 14),
            ),
        ],
      ),
    );
  }

  /// True when a RED X fault has been recorded against [phase] on the open
  /// session.
  bool hasRedX(PmcsPhase phase) => viewModel.sessionFaults.any(
        (fault) => fault.phase == phase && fault.severity == FaultSeverity.redX,
      );
}
