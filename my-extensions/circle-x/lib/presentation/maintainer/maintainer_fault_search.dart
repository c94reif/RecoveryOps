import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';

List<int> matchingFaultIndexes(
    PmcsReport report, List<String> descriptions, String query) {
  final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
  return [
    for (var index = 0; index < report.faults.length; index++)
      if (terms.every([
        report.faults[index].itemId,
        report.faults[index].phase.label,
        report.faults[index].category,
        report.faults[index].subcategory,
        report.faults[index].condition,
        report.faults[index].description,
        report.faults[index].note ?? '',
        descriptions[index],
      ].join(' ').toLowerCase().contains))
        index,
  ];
}

class MaintainerFaultSearch extends StatefulWidget {
  final PmcsReport report;
  final List<bool?> decisions;
  final List<String> descriptions;

  const MaintainerFaultSearch({
    super.key,
    required this.report,
    required this.decisions,
    required this.descriptions,
  });

  @override
  State<MaintainerFaultSearch> createState() => _MaintainerFaultSearchState();
}

class _MaintainerFaultSearchState extends State<MaintainerFaultSearch> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void clearSearch() => setState(controller.clear);

  Widget buildResult(int index) {
    final fault = widget.report.faults[index];
    final decision = widget.decisions[index];
    final color = decision == true ? serviceableGreen : circleXAmber;
    final status = switch (decision) {
      null => 'Not reviewed',
      true => 'Verified · draft',
      false => 'Not verified · draft',
    };
    return Card(
      key: ValueKey(('fault-search-result', index)),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Fault ${index + 1} · ${fault.phase.shortLabel} · ${fault.itemId}',
                style: const TextStyle(color: textSecondary, fontSize: 11)),
            const SizedBox(height: 6),
            Text(fault.subcategory,
                style: const TextStyle(
                    color: textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(fault.condition, style: const TextStyle(color: textSecondary)),
            if (fault.note?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text('Operator: ${fault.note}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textSecondary, fontSize: 12)),
            ],
            if (widget.descriptions[index].trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Maintainer: ${widget.descriptions[index]}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                  decision == null
                      ? Icons.pending_actions
                      : decision
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                  color: color,
                  size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(status,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, size: 20, color: textSecondary),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = matchingFaultIndexes(
        widget.report, widget.descriptions, controller.text);
    return FractionallySizedBox(
      heightFactor: .9,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Find a fault',
                            style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700))),
                    IconButton(
                        tooltip: 'Close fault search',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('fault-search-input'),
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Search faults',
                      hintText: 'Name, item ID, condition, or notes',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear fault search',
                              onPressed: clearSearch,
                              icon: const Icon(Icons.close)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                      liveRegion: true,
                      child: Text(
                          '${matches.length} of ${widget.report.faults.length} faults',
                          style: const TextStyle(
                              color: textSecondary, fontSize: 12))),
                  const SizedBox(height: 8),
                  Expanded(
                      child: matches.isEmpty
                          ? SingleChildScrollView(
                              child: Column(children: [
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('No faults match your search.',
                                      textAlign: TextAlign.center)),
                              TextButton(
                                  onPressed: clearSearch,
                                  child: const Text('Show all faults')),
                            ]))
                          : ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: matches.length,
                              itemBuilder: (_, index) =>
                                  buildResult(matches[index]),
                            )),
                ]),
          ),
        ),
      ),
    );
  }
}
