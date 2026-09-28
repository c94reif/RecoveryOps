import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_tally_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/fault_history_widgets.dart';
import 'package:ivy_pulse/presentation/common/widgets/phase_progress_bar.dart';
import 'package:ivy_pulse/presentation/common/widgets/section_label.dart';
import 'package:ivy_pulse/presentation/inspection/check_item_card.dart';
import 'package:ivy_pulse/presentation/inspection/fault_note_dialog.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key});

  @override
  State<InspectionPage> createState() => InspectionPageState();
}

class InspectionPageState extends State<InspectionPage> {
  late final InspectionViewModel viewModel;
  late final FaultClassifierStrategy classifier;

  final Map<String, GlobalKey> itemKeys = {};

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();
    classifier = getIt<FaultClassifierStrategy>();
  }

  GlobalKey keyFor(String itemId) =>
      itemKeys.putIfAbsent(itemId, () => GlobalKey());

  Future<void> editNote(PmcsCheckItem item) async {
    final open = viewModel.workspace;
    if (viewModel.isListening) {
      await viewModel.stopNoteDictation(discardResult: true);
    }
    if (!mounted || !identical(open, viewModel.workspace)) return;
    final answer = viewModel.results[item.id];
    if (answer == null || !answer.isFault) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FaultNoteDialog(
        itemName: item.item,
        condition: answer.faultLabel,
        initialNote: answer.note,
        onSave: (note) async {
          if (!identical(open, viewModel.workspace)) return false;
          return viewModel.saveNote(item, note);
        },
      ),
    );
  }

  void honourPendingScroll() {
    final itemId = viewModel.consumePendingScroll();
    if (itemId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = itemKeys[itemId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.suggestions]),
      builder: (context, _) {
        final session = viewModel.session;
        final phase = viewModel.activePhase;
        if (session == null || phase == null) return const SizedBox.shrink();

        honourPendingScroll();

        return Column(
          children: [
            buildHeader(),
            Expanded(child: buildCheckList()),
            buildBottomBar(),
          ],
        );
      },
    );
  }

  Widget buildHeader() {
    final session = viewModel.session!;
    final phase = viewModel.activePhase!;
    final tally = viewModel.phaseTally;

    return Container(
      decoration: const BoxDecoration(
        color: bgDark,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: minTouchTarget,
            child: Row(
              children: [
                SizedBox(
                  width: minTouchTarget,
                  height: minTouchTarget,
                  child: IconButton(
                    onPressed: viewModel.isBusy
                        ? null
                        : viewModel.reviewingSummaryFault
                            ? viewModel.returnToSummary
                            : viewModel.backToPhases,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: masterChiefGreen,
                    tooltip: viewModel.reviewingSummaryFault
                        ? 'Back to summary'
                        : 'PMCS types',
                  ),
                ),
                Expanded(
                  child: Text(
                    session.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  phase.shortLabel,
                  style: TextStyle(
                    color: masterChiefGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    viewModel.isBusy
                        ? 'Saving…'
                        : '${viewModel.answeredCount}/${viewModel.totalCount}',
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (viewModel.nextUnansweredItemId != null &&
                    viewModel.expandedItemId != viewModel.nextUnansweredItemId)
                  IconButton(
                    onPressed:
                        viewModel.isBusy ? null : viewModel.continueToNextCheck,
                    tooltip: 'Next unanswered check',
                    icon: const Icon(Icons.skip_next, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: minTouchTarget,
                      minHeight: minTouchTarget,
                    ),
                  ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          if (!tally.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: FaultTallyBar(tally: tally),
            ),
          PhaseProgressBar(
            done: viewModel.answeredCount,
            total: viewModel.totalCount,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget buildCheckList() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.historyUnavailable)
            const Text(
                'Previous PMCS history unavailable. You can continue '
                'this inspection.',
                style: TextStyle(color: textSecondary)),
          for (final category in viewModel.phaseCategories) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: SectionLabel(text: category.name),
            ),
            for (final item in category.items)
              CheckItemCard(
                key: keyFor(item.id),
                item: item,
                previousFinding: previousFinding(item),
                result: viewModel.results[item.id],
                isExpanded: viewModel.isItemExpanded(item.id),
                isDictating: viewModel.isListening &&
                    viewModel.listeningItemId == item.id,
                classifier: classifier,
                enabled: !viewModel.isBusy,
                onAnswer: (faultIndex) => viewModel.answer(item, faultIndex),
                onExpand: () => viewModel.expandItem(item.id),
                onCollapse: () => viewModel.collapseItem(item.id),
                onDictateNote: () => viewModel.toggleNoteDictation(item),
                onEditNote: () => editNote(item),
              ),
          ],
        ],
      ),
    );
  }

  Widget? previousFinding(PmcsCheckItem item) {
    final phase = viewModel.activePhase;
    if (phase == null) return null;
    final previous = viewModel.history?.previousFault(phase, item.id);
    if (previous == null) return null;
    final controller = viewModel.suggestions;
    final hidden = controller.dismissed.contains(previous.suggestionId);
    final condition = item.faults.indexOf(previous.fault.condition);
    final enabled = !viewModel.isBusy;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!hidden) ...[
        Text(
            'Previously: ${previous.fault.condition} '
            '(${previous.fault.severity.label}) · '
            '${historyDate(context, previous.report.timestamp)}',
            style: const TextStyle(color: circleXAmber, fontSize: 12)),
        if (previous.fault.note?.isNotEmpty == true)
          Text('Previous note: ${previous.fault.note}',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        const Text('Suggestion only — select what you find today.',
            style: TextStyle(color: textSecondary, fontSize: 12)),
      ],
      Wrap(spacing: 8, children: [
        if (!hidden && condition > 0)
          TextButton(
            onPressed: enabled
                ? () => viewModel.answer(item, condition,
                    suggestedNote: previous.fault.note)
                : null,
            child: const Text('Still present'),
          ),
        TextButton(
          onPressed: enabled &&
                  controller.loaded &&
                  !controller.saving.contains(previous.suggestionId)
              ? () => controller.setDismissed(previous.suggestionId, !hidden)
              : null,
          child: Text(
              hidden ? 'Restore previous suggestion' : 'Dismiss suggestion'),
        ),
      ]),
    ]);
  }

  Widget buildBottomBar() {
    if (!viewModel.isPhaseComplete) return const SizedBox.shrink();

    final hasRedX = viewModel.phaseTally.redX > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const BoxDecoration(
        color: bgDark,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SizedBox(
        height: minTouchTarget,
        child: CustomButton(
          text: hasRedX ? 'REVIEW & SUBMIT — RED X' : 'REVIEW & SUBMIT',
          icon: hasRedX ? Icons.dangerous_outlined : Icons.check,
          color: hasRedX ? redXRed : null,
          onPressed: viewModel.isBusy ? null : viewModel.completeActivePhase,
        ),
      ),
    );
  }
}
