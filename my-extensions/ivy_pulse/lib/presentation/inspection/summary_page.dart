import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_history_widgets.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/common/widgets/inspection_fault_card.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off_card.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => SummaryPageState();
}

class SummaryPageState extends State<SummaryPage> {
  late final InspectionViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();
  }

  String get statusLabel => viewModel.sessionTally.missionCapabilityLabel;

  String get statusDetail => viewModel.sessionTally.missionCapabilityDetail;

  Color get statusColor {
    final worst = viewModel.sessionTally.worst;
    return worst == null ? serviceableGreen : severityColor(worst);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final session = viewModel.session;
        if (session == null) return const SizedBox.shrink();

        final tally = viewModel.sessionTally;

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
              session.uic,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            buildInspectionSummary(),
            const SizedBox(height: 16),
            buildStatusBanner(),
            if (!tally.isEmpty) ...[
              const SizedBox(height: 12),
              FaultTallyBar(tally: tally),
            ],
            const SizedBox(height: 20),
            ...buildFaultGroups(),
            if (viewModel.historyUnavailable)
              const Text(
                  'Previous PMCS history unavailable. You can still submit.')
            else ...[
              PmcsChanges(comparisons: viewModel.comparisons),
              const SizedBox(height: 12),
              FaultSuggestions(
                  suggestions: viewModel.summarySuggestions,
                  controller: viewModel.suggestions),
            ],
            const SizedBox(height: 12),
            SignOffCard(viewModel: viewModel),
            const SizedBox(height: 10),
            const Text(
              'Goes out on Lattice and the tactical mesh at the same time. '
              'Either leg that is down queues and re-sends itself when it '
              'comes back up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                viewModel.sessionTally.isDeadlined
                    ? Icons.dangerous_outlined
                    : Icons.verified_outlined,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusDetail,
            style: TextStyle(color: statusColor, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget buildInspectionSummary() {
    final session = viewModel.session!;
    final otherSaved = PmcsPhase.values.where((phase) =>
        !session.isPhaseComplete(phase) &&
        viewModel.answeredCountFor(phase) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(text: 'READY TO SUBMIT'),
        const SizedBox(height: 8),
        for (final phase in session.completedPhases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: serviceableGreen),
                const SizedBox(width: 8),
                Expanded(child: Text('${phase.label} PMCS')),
                Flexible(
                  child: TextButton(
                    onPressed: viewModel.isBusy
                        ? null
                        : () => viewModel.reviewPhase(phase),
                    child: const Text('Review checks'),
                  ),
                ),
              ],
            ),
          ),
        for (final phase in otherSaved)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Saved ${phase.label} checks are not included in this report.',
                    style: const TextStyle(color: circleXAmber, fontSize: 12)),
                TextButton(
                  onPressed: viewModel.isBusy
                      ? null
                      : () => viewModel.reviewPhase(phase),
                  child: const Text('Review saved checks'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> buildFaultGroups() {
    if (viewModel.sessionFaults.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No faults recorded',
            textAlign: TextAlign.center,
            style: TextStyle(color: masterChiefGreen, fontSize: 16),
          ),
        ),
      ];
    }

    final groups = <Widget>[];
    for (final severity in FaultSeverity.values) {
      final faults = viewModel.sessionFaults
          .where((fault) => fault.severity == severity)
          .toList();
      if (faults.isEmpty) continue;

      groups.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: SectionLabel(text: '${severity.label} — ${faults.length}'),
        ),
      );
      groups.addAll(faults.map(buildFaultCard));
    }
    return groups;
  }

  Widget buildFaultCard(PmcsFault fault) => InspectionFaultCard(
        fault: fault,
        onReview: viewModel.isBusy ? null : () => viewModel.reviewFault(fault),
      );
}
