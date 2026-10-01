import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/check_result.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/pmcs_check_item.dart';
import 'package:circle_x/domain/services/fault_classifier_strategy.dart';
import 'package:circle_x/presentation/inspection/check_item/check_item_styles.dart';
import 'package:circle_x/presentation/inspection/check_item/fault_note_controls.dart';
import 'package:circle_x/presentation/inspection/check_item/collapsed_check_summary.dart';
import 'package:circle_x/presentation/inspection/check_item/check_condition_buttons.dart';

class CheckItemCard extends StatelessWidget {
  final PmcsCheckItem item;
  final CheckResult? result;
  final bool isExpanded;
  final bool isDictating;
  final FaultClassifierStrategy classifier;
  final void Function(int faultIndex) onAnswer;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onDictateNote;
  final VoidCallback? onEditNote;
  final bool enabled;
  final Widget? previousFinding;

  const CheckItemCard({
    super.key,
    required this.item,
    required this.result,
    required this.isExpanded,
    required this.isDictating,
    required this.classifier,
    required this.onAnswer,
    required this.onExpand,
    required this.onCollapse,
    required this.onDictateNote,
    this.onEditNote,
    this.enabled = true,
    this.previousFinding,
  });

  static const Color recordingRed = FaultNoteControls.recordingRed;

  Color get accentColor {
    final answer = result;
    if (answer == null) return border;
    final severity = answer.severity;
    return severity == null ? serviceableGreen : severityColor(severity);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: accentColor,
          width: result == null ? 1 : 1.5,
        ),
      ),
      child: isExpanded
          ? buildExpanded(context)
          : CollapsedCheckSummary(
              item: item,
              result: result,
              enabled: enabled,
              isDictating: isDictating,
              onExpand: onExpand,
              onDictateNote: onDictateNote,
              onEditNote: onEditNote,
            ),
    );
  }

  Widget buildExpanded(BuildContext context) {
    final answer = result;
    final severity = answer?.severity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: answer == null || !enabled ? null : onCollapse,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.id, style: checkItemIdStyle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (answer != null)
                      const Icon(
                        Icons.expand_less,
                        color: textSecondary,
                        size: 18,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
          child: Text(
            item.check,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        if (answer != null && severity != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: buildSelectionBanner(answer, severity),
          ),
        ],
        if (previousFinding != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: previousFinding,
          ),
        const SizedBox(height: 8),
        CheckConditionButtons(
          item: item,
          result: result,
          enabled: enabled,
          classifier: classifier,
          onAnswer: onAnswer,
        ),
        if (answer != null && answer.isFault)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 10, bottom: 2),
            child: FaultNoteControls(
              answer: answer,
              isDictating: isDictating,
              enabled: enabled,
              onDictateNote: onDictateNote,
              onEditNote: onEditNote,
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }

  Widget buildSelectionBanner(CheckResult answer, FaultSeverity severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: severityGlow(severity),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: severityColor(severity), width: 1),
      ),
      child: Row(
        children: [
          Icon(severityIcon(severity),
              color: severityColor(severity), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${severity.label} — ${answer.faultLabel}',
              style: TextStyle(
                color: severityColor(severity),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
