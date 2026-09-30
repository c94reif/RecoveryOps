import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/presentation/inspection/check_item/check_item_styles.dart';
import 'package:ivy_pulse/presentation/inspection/check_item/fault_note_controls.dart';
import 'package:ivy_pulse/presentation/common/widgets/severity_badge.dart';

class CollapsedCheckSummary extends StatelessWidget {
  final PmcsCheckItem item;
  final CheckResult? result;
  final bool enabled;
  final VoidCallback onExpand;
  final VoidCallback? onEditNote;

  const CollapsedCheckSummary({
    super.key,
    required this.item,
    required this.result,
    required this.enabled,
    required this.onExpand,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
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
                child: Text(item.id, style: checkItemIdStyle),
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
                        Text(item.id, style: checkItemIdStyle),
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
                  label: Text(faultNoteActionLabel(answer)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildServiceableAnswer() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: serviceableGreen, size: 20),
        const SizedBox(width: 6),
        Text('OK', style: checkItemOkStyle),
      ],
    );
  }
}
