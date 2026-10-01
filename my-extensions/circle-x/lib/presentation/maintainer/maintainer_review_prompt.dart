import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';

class MaintainerReviewPrompt extends StatelessWidget {
  final VoidCallback onReview;

  const MaintainerReviewPrompt({
    super.key,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.pending_actions, color: circleXAmber, size: 16),
            SizedBox(width: 6),
            Expanded(
                child: Text('NOT REVIEWED',
                    style: TextStyle(
                        color: circleXAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1))),
          ]),
          const SizedBox(height: 4),
          const Text('Add notes and sign your review with your CAC.',
              style:
                  TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onReview,
            style: OutlinedButton.styleFrom(
              foregroundColor: circleXAmber,
              backgroundColor: circleXGlow,
              side: const BorderSide(color: circleXAmber),
              minimumSize: const Size(0, minTouchTarget),
            ),
            icon: const Icon(Icons.swipe_outlined, size: 18),
            label: const Text('Review faults', textAlign: TextAlign.center),
          ),
        ],
      );
}
