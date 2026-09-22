import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/services/fault_classifier_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';

/// One TM check.
///
/// Answered checks fold down to a single row so the operator's eye lands on
/// what is still owed; the open state puts every condition one tap away with
/// no confirm step behind it.
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
  });

  static const Color recordingRed = Color(0xFFE53935);

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
      child: isExpanded ? buildExpanded(context) : buildCollapsed(context),
    );
  }

  Widget buildCollapsed(BuildContext context) {
    final answer = result;
    if (answer != null && answer.isFault) return buildCollapsedFault(answer);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onExpand : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(item.id, style: idStyle),
              ),
              Expanded(
                child: Text(
                  item.item,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              if (answer != null) buildServiceableAnswer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCollapsedFault(CheckResult answer) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onExpand : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minTouchTarget),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.id, style: idStyle),
                        Text(item.item,
                            style: const TextStyle(
                                color: textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (answer.severity case final severity?) ...[
                  SeverityBadge(severity: severity),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(answer.faultLabel,
                      style: const TextStyle(color: textPrimary, fontSize: 12)),
                ),
              ],
            ),
            if (onEditNote != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: enabled ? onEditNote : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, minTouchTarget),
                  ),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: Text(noteActionLabel(answer)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String noteActionLabel(CheckResult answer) =>
      answer.note?.isNotEmpty == true ? 'Edit description' : 'Add description';

  Widget buildServiceableAnswer() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: serviceableGreen, size: 20),
        const SizedBox(width: 6),
        Text('OK', style: okStyle),
      ],
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
                // The TM number and the component share a line: two lines of
                // header is a line of the check instruction the operator does
                // not get to read.
                Row(
                  children: [
                    Text(item.id, style: idStyle),
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: buildServiceableButton(),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: buildFaultGrid(),
        ),
        if (answer != null && answer.isFault)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 10, bottom: 2),
            child: buildNoteRow(answer),
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

  /// Serviceable is the common answer, so it is the biggest target on the
  /// card and never shares a row with anything else.
  Widget buildServiceableButton() {
    final isSelected = result?.faultIndex == 0;
    return SizedBox(
      width: double.infinity,
      height: faultButtonHeight,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => onAnswer(0) : null,
        icon: Icon(
          isSelected ? Icons.check_circle : Icons.check_circle_outline,
          size: 20,
        ),
        label: Text(
          item.serviceableLabel.toUpperCase(),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: serviceableGreen,
          backgroundColor:
              isSelected ? serviceableGreen.withAlpha(70) : serviceableGlow,
          side: BorderSide(
            color: serviceableGreen,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget buildFaultGrid() {
    final rows = <Widget>[];
    for (var index = 1; index < item.faults.length; index += 2) {
      final hasSecond = index + 1 < item.faults.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          // Each button already carries its own height. Stretching the row
          // instead would hand its children the column's unbounded height and
          // fail layout outright, taking the whole checklist down with it.
          child: Row(
            children: [
              Expanded(child: buildFaultButton(index)),
              const SizedBox(width: 8),
              Expanded(
                child: hasSecond
                    ? buildFaultButton(index + 1)
                    : const SizedBox(height: faultButtonHeight),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget buildFaultButton(int faultIndex) {
    // Grading the option up front means the operator sees what a condition
    // costs the vehicle before they commit to it.
    final severity = classifier.classify(
      itemId: item.id,
      faultIndex: faultIndex,
    );
    final color = severity == null ? serviceableGreen : severityColor(severity);
    final glow = severity == null ? serviceableGlow : severityGlow(severity);
    final isSelected = result?.faultIndex == faultIndex;

    return SizedBox(
      height: faultButtonHeight,
      child: OutlinedButton(
        onPressed: enabled ? () => onAnswer(faultIndex) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: isSelected ? color.withAlpha(70) : glow,
          side: BorderSide(color: color, width: isSelected ? 2 : 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.labelAt(faultIndex),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            if (severity != null) ...[
              const SizedBox(height: 2),
              Text(
                severity.label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildNoteRow(CheckResult answer) {
    final note = answer.note;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildMicButton(),
        Expanded(
          child: Text(
            note == null || note.isEmpty
                ? 'Optional description · up to 155 characters'
                : note,
            style: TextStyle(
              color: note == null || note.isEmpty ? textSecondary : textPrimary,
              fontSize: 12,
              fontStyle: note == null || note.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        if (onEditNote != null)
          IconButton(
            onPressed: enabled ? onEditNote : null,
            tooltip: noteActionLabel(answer),
            icon: const Icon(Icons.edit_note),
            constraints: const BoxConstraints(
              minWidth: minTouchTarget,
              minHeight: minTouchTarget,
            ),
          ),
      ],
    );
  }

  Widget buildMicButton() {
    return IconButton(
      onPressed: enabled ? onDictateNote : null,
      icon: Icon(
        isDictating ? Icons.mic : Icons.mic_none,
        color: isDictating ? recordingRed : masterChiefGreen,
        size: 24,
      ),
      style: IconButton.styleFrom(
        backgroundColor:
            isDictating ? recordingRed.withAlpha(38) : Colors.transparent,
        shape: const CircleBorder(),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
      ),
      tooltip: isDictating ? 'Recording — tap to stop' : 'Tap to record',
    );
  }

  TextStyle get idStyle => TextStyle(
        color: masterChiefGreen,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );

  TextStyle get okStyle => const TextStyle(
        color: serviceableGreen,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );
}
