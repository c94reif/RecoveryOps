import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/check_result.dart';
import 'package:circle_x/domain/entities/pmcs_check_item.dart';
import 'package:circle_x/domain/services/fault_classifier_strategy.dart';

class CheckConditionButtons extends StatelessWidget {
  final PmcsCheckItem item;
  final CheckResult? result;
  final bool enabled;
  final FaultClassifierStrategy classifier;
  final ValueChanged<int> onAnswer;

  const CheckConditionButtons({
    super.key,
    required this.item,
    required this.result,
    required this.enabled,
    required this.classifier,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: buildServiceableButton(),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: buildFaultGrid(),
        ),
      ],
    );
  }

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
}
