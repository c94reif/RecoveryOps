import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_history.dart';
import 'package:circle_x/presentation/common/services/fault_suggestion_controller.dart';

String historyDate(BuildContext context, DateTime timestamp) =>
    MaterialLocalizations.of(context).formatMediumDate(timestamp.toLocal());

class FaultSuggestions extends StatelessWidget {
  final List<HistoricalFault> suggestions;
  final FaultSuggestionController controller;

  const FaultSuggestions(
      {super.key, required this.suggestions, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = suggestions
            .where((suggestion) =>
                !controller.dismissed.contains(suggestion.suggestionId))
            .toList();
        final hidden = suggestions
            .where((suggestion) =>
                controller.dismissed.contains(suggestion.suggestionId))
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suggested unresolved faults · ${active.length}',
                    style: const TextStyle(
                        color: circleXAmber, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text(
                    'Previous findings to consider. Suggestions do not '
                    'change this PMCS or block submission. Dismissals are saved '
                    'on this device.',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                if (controller.loadFailed)
                  TextButton(
                      onPressed: controller.load,
                      child: const Text('Reload suggestion preferences')),
                for (final suggestion in active)
                  _buildSuggestionRow(context, suggestion, false),
                if (hidden.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Dismissed suggestions (${hidden.length})',
                        style: const TextStyle(fontSize: 13)),
                    children: [
                      for (final suggestion in hidden)
                        _buildSuggestionRow(context, suggestion, true)
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionRow(
      BuildContext context, HistoricalFault suggestion, bool hidden) {
    final fault = suggestion.fault;
    final id = suggestion.suggestionId;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${fault.subcategory} — ${fault.condition}',
            style: const TextStyle(fontSize: 13)),
        Text(
            '${fault.severity.label} · ${fault.phase.label} · '
            '${historyDate(context, suggestion.report.timestamp)}',
            style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (fault.note?.isNotEmpty == true)
          Text('Previous note: ${fault.note}',
              style: const TextStyle(fontSize: 12)),
        TextButton(
          key: ValueKey('suggestion-$id'),
          onPressed: !controller.loaded || controller.saving.contains(id)
              ? null
              : () => controller.setDismissed(id, !hidden),
          child: Text(hidden ? 'Restore suggestion' : 'Dismiss suggestion'),
        ),
      ]),
    );
  }
}

class PmcsChanges extends StatelessWidget {
  final List<PhaseComparison> comparisons;

  const PmcsChanges({super.key, required this.comparisons});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text('Changes since previous PMCS',
              style: TextStyle(fontWeight: FontWeight.w600)),
          if (comparisons.isEmpty)
            const Text('Inspection type unavailable; no comparison available.',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          for (final comparison in comparisons) ...[
            const SizedBox(height: 6),
            if (comparison.previous == null)
              Text(
                  'No previous ${comparison.phase.label} PMCS available to compare.',
                  style: const TextStyle(color: textSecondary, fontSize: 12))
            else ...[
              Text(
                  '${comparison.phase.label} · compared with '
                  '${historyDate(context, comparison.previous!.timestamp)}',
                  style: const TextStyle(color: textSecondary, fontSize: 12)),
              if (comparison.changes.isEmpty)
                const Text(
                    'No fault changes; both inspections reported no faults.',
                    style: TextStyle(fontSize: 12)),
              for (final change in comparison.changes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${_changeKindLabel(change.kind)} · ${change.fault.subcategory}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(_changeDetail(change),
                          style: const TextStyle(
                              color: textSecondary, fontSize: 12)),
                      if (change.kind == FaultChangeKind.changed &&
                          change.previous?.note != change.current?.note)
                        Text(
                            'Note: ${change.previous?.note ?? "None"} → '
                            '${change.current?.note ?? "None"}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ],
          if (comparisons.any((comparison) => comparison.changes.any(
              (change) => change.kind == FaultChangeKind.noLongerReported)))
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'No longer reported means absent from this inspection; '
                    'it is not a maintenance clearance.',
                    style: TextStyle(color: textSecondary, fontSize: 12))),
        ],
      );

  String _changeKindLabel(FaultChangeKind kind) => switch (kind) {
        FaultChangeKind.newFault => 'New',
        FaultChangeKind.recurring => 'Recurring',
        FaultChangeKind.changed => 'Changed',
        FaultChangeKind.noLongerReported => 'No longer reported',
      };

  String _changeDetail(FaultChange change) {
    final before = change.previous;
    final current = change.current;
    if (current == null) {
      return 'Previously: ${before!.condition} (${before.severity.label})';
    }
    if (before != null && change.kind == FaultChangeKind.changed) {
      return '${before.condition} (${before.severity.label}) → '
          '${current.condition} (${current.severity.label})';
    }
    return '${current.condition} (${current.severity.label})';
  }
}
