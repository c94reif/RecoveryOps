import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';

class MaintainerReviewSummary extends StatelessWidget {
  final MaintainerReview review;
  const MaintainerReviewSummary({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final verified = review.faults.where((fault) => fault.verified).length;
    final signedAt = review.signature.signedAt.toLocal();
    final labels = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MAINTAINER REVIEW',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 6),
          Text(
              '$verified verified · ${review.faults.length - verified} not verified'),
          Text('CAC signed by ${review.signature.displayName}',
              style: const TextStyle(color: serviceableGreen)),
          Text(
              '${labels.formatMediumDate(signedAt)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(signedAt), alwaysUse24HourFormat: true)}',
              style: const TextStyle(fontSize: 11)),
          for (final fault in review.faults)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${fault.phase.shortLabel} · ${fault.itemId}: ${fault.verified ? 'Verified' : 'Not verified'}${fault.description.isEmpty ? '' : '\n${fault.description}'}',
                  style: const TextStyle(color: textPrimary, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
