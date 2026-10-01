import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';

class MaintainerReviewSummary extends StatefulWidget {
  final MaintainerReview review;
  final List<PmcsFault> faults;

  const MaintainerReviewSummary({
    super.key,
    required this.review,
    required this.faults,
  });

  @override
  State<MaintainerReviewSummary> createState() =>
      _MaintainerReviewSummaryState();
}

class _MaintainerReviewSummaryState extends State<MaintainerReviewSummary> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final verified = review.faults.where((fault) => fault.verified).length;
    final signedAt = review.signature.signedAt.toLocal();
    final labels = MaterialLocalizations.of(context);
    final sourceFaults = {
      for (final fault in widget.faults) (fault.phase, fault.itemId): fault,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.assignment_turned_in_outlined,
              color: serviceableGreen, size: 18),
          SizedBox(width: 6),
          Expanded(
            child: Text('MAINTAINER REVIEW',
                style: TextStyle(
                    color: serviceableGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _DecisionBadge(verified: true, label: '$verified verified'),
          _DecisionBadge(
              verified: false,
              label: '${review.faults.length - verified} not verified'),
        ]),
        const SizedBox(height: 10),
        Text('CAC signed by ${review.signature.displayName}',
            style:
                const TextStyle(color: textPrimary, fontSize: 12, height: 1.4)),
        const SizedBox(height: 2),
        Text(
            '${labels.formatMediumDate(signedAt)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(signedAt), alwaysUse24HourFormat: true)}',
            style: const TextStyle(color: textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => setState(() => expanded = !expanded),
          style: TextButton.styleFrom(
              foregroundColor: serviceableGreen,
              minimumSize: const Size(0, minTouchTarget)),
          icon:
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text(expanded
              ? 'Hide review details'
              : 'View review details (${review.faults.length})'),
        ),
        if (expanded)
          for (final fault in review.faults) ...[
            const Divider(height: 1),
            _ReviewedFaultLine(
              review: fault,
              fault: sourceFaults[fault.key],
            ),
          ],
      ],
    );
  }
}

class _ReviewedFaultLine extends StatelessWidget {
  final FaultReview review;
  final PmcsFault? fault;

  const _ReviewedFaultLine({required this.review, required this.fault});

  @override
  Widget build(BuildContext context) {
    final title = [fault?.subcategory, fault?.condition]
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join(' — ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DecisionBadge(
            verified: review.verified,
            label: review.verified ? 'Verified' : 'Not verified'),
        const SizedBox(height: 6),
        Text(title.isEmpty ? 'Fault ${review.itemId}' : title,
            style: const TextStyle(
                color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${review.phase.shortLabel} · ${review.itemId}',
            style: const TextStyle(color: textSecondary, fontSize: 10)),
        if (review.description.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Maintainer note: ${review.description.trim()}',
              style: const TextStyle(
                  color: textPrimary, fontSize: 12, height: 1.4)),
        ],
      ]),
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  final bool verified;
  final String label;

  const _DecisionBadge({required this.verified, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = verified ? serviceableGreen : circleXAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: verified ? serviceableGlow : circleXGlow,
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(verified ? Icons.check : Icons.close, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
