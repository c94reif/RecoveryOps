import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off_card.dart';

/// What the maintainer is about to receive, in the operator's words, before
/// it goes on the net.
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

  /// Read off the same tally the submitted report grades itself from, so the
  /// summary and the card a maintainer opens later can never disagree.
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
            buildStatusBanner(),
            if (!tally.isEmpty) ...[
              const SizedBox(height: 12),
              FaultTallyBar(tally: tally),
            ],
            const SizedBox(height: 20),
            ...buildFaultGroups(),
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: viewModel.backToPhases,
              child: const Text('BACK TO PHASES'),
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
    // FaultSeverity.values is ordered most to least severe, so the deadlining
    // faults are the first thing read.
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

  Widget buildFaultCard(PmcsFault fault) {
    final color = severityColor(fault.severity);
    final note = fault.note;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fault.itemId,
                  style: TextStyle(
                    color: masterChiefGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                SeverityBadge(severity: fault.severity),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fault.subcategory,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${fault.category} · ${fault.phase.shortLabel}',
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              fault.condition,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    color: textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
