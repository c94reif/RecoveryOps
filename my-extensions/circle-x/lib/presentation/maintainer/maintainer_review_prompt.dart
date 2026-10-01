import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';

class MaintainerReviewPrompt extends StatelessWidget {
  final PmcsReport report;
  final VoidCallback onReview;

  const MaintainerReviewPrompt({
    super.key,
    required this.report,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 4, bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: circleXGlow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: circleXAmber),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Icon(Icons.pending_actions, color: circleXAmber, size: 22),
              SizedBox(width: 10),
              Expanded(
                  child: Text('NOT REVIEWED',
                      style: TextStyle(
                          color: circleXAmber,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1))),
            ]),
            const SizedBox(height: 10),
            Text(
                '${report.faults.length} ${report.faults.length == 1 ? 'fault needs' : 'faults need'} a signed review',
                style: const TextStyle(
                    color: textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
                'Review each fault, add your notes, then submit with your CAC.',
                style:
                    TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReview,
              style: OutlinedButton.styleFrom(
                foregroundColor: circleXAmber,
                backgroundColor: bgDark,
                side: const BorderSide(color: circleXAmber),
                minimumSize: const Size(0, minTouchTarget),
              ),
              icon: const Icon(Icons.swipe_outlined, size: 18),
              label: const Text('Review faults', textAlign: TextAlign.center),
            ),
          ],
        ),
      );
}
