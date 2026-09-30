import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/inspection/sign_off/scan_guidance.dart';

class SignOffPrompt extends StatelessWidget {
  final bool scansBothSides;
  final bool scannerAvailable;
  final bool isBusy;
  final VoidCallback onScan;

  const SignOffPrompt({
    super.key,
    required this.scansBothSides,
    required this.scannerAvailable,
    required this.isBusy,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scansBothSides
              ? 'A PMCS is signed by the Soldier who walked it. Scan the front '
                  'of your CAC for your name, then flip it when asked to read '
                  'the DoD ID number on the back.'
              : 'A PMCS is signed by the Soldier who walked it. Show the camera '
                  'the back of your CAC — it reads your DoD ID number.',
          style:
              const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
        ),
        if (scannerAvailable) ...[
          const SizedBox(height: 10),
          CacAimGuide(scansBothSides: scansBothSides),
        ] else ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: circleXAmber, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No camera reachable on this device — you will be offered an '
                  'unverified submission instead.',
                  style: TextStyle(
                    color: circleXAmber,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        CustomButton(
          text: 'SCAN CAC',
          icon: Icons.badge_outlined,
          onPressed: isBusy ? null : onScan,
        ),
      ],
    );
  }
}
