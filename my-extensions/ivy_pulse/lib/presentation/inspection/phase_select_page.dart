import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/confirm_dialog.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

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
            const SectionLabel(text: 'CHOOSE PMCS TYPE'),
            const SizedBox(height: 6),
            const Text(
              'Choose the inspection you are performing. Submit it when finished.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final phase in PmcsPhase.values)
              buildPhaseCard(phase, session.isPhaseComplete(phase)),
            const SizedBox(height: 20),
            if (session.hasStartedAnyPhase)
              CustomButton(
                text: 'REVIEW & SUBMIT PMCS',
                icon: Icons.assignment_outlined,
                onPressed: viewModel.openSummary,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: viewModel.isBusy ? null : discard,
              style: TextButton.styleFrom(
                foregroundColor: textSecondary,
                minimumSize: const Size(0, minTouchTarget),
              ),
              child: const Text('Discard session'),
            ),
          ],
        );
      },
    );
  }

  Widget buildPhaseCard(PmcsPhase phase, bool isComplete) {
    final itemCount = viewModel.catalog?.itemCountFor(phase) ?? 0;
    final answered = viewModel.answeredCountFor(phase);
    final status = isComplete
        ? 'READY TO SUBMIT'
        : answered > 0
            ? 'IN PROGRESS'
            : null;
    final progress = isComplete || answered > 0
        ? '${isComplete ? itemCount : answered} of $itemCount complete'
        : '$itemCount ${itemCount == 1 ? 'check' : 'checks'}';
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
            onTap: viewModel.isBusy
                ? null
                : isComplete
                    ? viewModel.openSummary
                    : () => viewModel.openPhase(phase),
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
                          progress,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (status != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            status,
                            style: TextStyle(
                              color:
                                  isComplete ? serviceableGreen : textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isComplete)
                    const Icon(
                      Icons.check_circle,
                      color: serviceableGreen,
                      size: 22,
                    )
                  else
                    Icon(Icons.chevron_right, color: accent, size: 24),
                ],
              ),
            ),
          ),
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

  bool hasRedX(PmcsPhase phase) => viewModel.sessionFaults.any(
        (fault) => fault.phase == phase && fault.severity == FaultSeverity.redX,
      );
}
